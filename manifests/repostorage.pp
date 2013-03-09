# a gitloite repostorage
define gitolite::repostorage(
  $ensure             = 'present',
  $initial_admin      = 'absent',
  $initial_sshkey     = 'absent',
  $password           = 'absent',
  $password_crypted   = true,
  $uid                = 'absent',
  $gid                = 'uid',
  $manage_user_group  = true,
  $basedir            = 'absent',
  $allowdupe_user     = false,
  $git_daemon         = false,
  $git_vhost          = 'absent',
  $rc_options         = {}
){

  if ($ensure == 'present') and (($initial_sshkey == 'absent') or ($initial_admin == 'absent')) {
    fail("You need to pass \$initial_sshkey if repostorage ${name} should be present!")
  }
  include ::gitolite

  $real_password = $password ? {
    'trocla'  => trocla("gitolite_${name}",'sha512crypt'),
    default   => $password
  }

  $real_basedir = $basedir ? {
    'absent' => "/home/${name}",
    default => $basedir
  }

  $real_uid = $uid ? {
    'iuid'  => iuid($name,'gitolite'),
    default => $uid
  }
  $real_gid = $gid ? {
    'iuid'  => iuid($name,'gitolite'),
    default => $gid
  }

  user::managed{$name:
    ensure            => $ensure,
    homedir           => $real_basedir,
    allowdupe         => $allowdupe_user,
    uid               => $real_uid,
    gid               => $real_gid,
    manage_group      => $manage_user_group,
    password          => $real_password,
    password_crypted  => $password_crypted,
  }


  include gitolite::gitaccess
  $gitolited_ensure = $ensure ? {
    absent  => 'absent',
    default => $git_daemon ? {
      true    => 'present',
      default => 'absent'
    }
  }
  user::groups::manage_user{
    $name:
      ensure => $ensure,
      group  => 'gitaccess';
    "gitolited_in_${name}":
      ensure => $gitolited_ensure,
      user   => 'gitolited'
      group  => $name;
  }

  if $ensure == 'present' {
    User::Groups::Manage_user[$name]{
      require => [ Group['gitaccess'], User::Managed[$name] ],
    }

    $default_rc = {
      umask                 => '0077',
      git_config_keys       => [ # some sane defaults
        'gitweb.owner', 'gitweb.description', 'gitweb.category',
        'hooks.mailinglist', 'hooks.emailprefix', 'hooks.announcelist',
        'hooks.envelopesender', 'hooks.generatepatch'
      ],
      extra_git_config_keys => [],
      log_extra             => false, #privacy by default
      external_settings     => {},
      commands              => [
        'help', 'desc', 'info', 'perms', 'writable',
      ],
      extra_commands        => [],
      syntactic_sugar       => [],
      input                 => [],
      access_1              => [],
      pre_git               => [],
      access_2              => [],
      post_git              => [],
      pre_create            => [],
      post_create           => [
        'post-compile/update-git-configs',
        'post-compile/update-gitweb-access-list',
        'post-compile/update-git-daemon-access-list', ],
      extra_post_create     => [],
      post_compile          => [
        'post-compile/ssh-authkeys',
        'post-compile/update-git-configs',
        'post-compile/update-gitweb-access-list',
        'post-compile/update-git-daemon-access-list', ],
      extra_post_compile    => [],
    }
    $rc = merge($default_rc, $rc_options)

    file{
      "${real_basedir}/${initial_admin}.pub":
        content => "${initial_sshkey}\n",
        owner   => $name,
        group   => $name,
        mode    => '0600';
      "${real_basedir}/.gitolite.rc":
        content => template('gitolite/gitolite.rc.erb'),
        owner   => $name,
        group   => $name,
        mode    => '0600';
    }
    exec{"create_gitolite_${name}":
      command     => "gitolite setup -pk ${real_basedir}/${initial_admin}.pub",
      environment => [ "HOME=${real_basedir}" ],
      unless      => "test -d ${real_basedir}/repositories",
      cwd         => $real_basedir,
      user        => $name,
      group       => $name,
      require     => [ Package['gitolite'], File["${real_basedir}/${initial_admin}.pub","${real_basedir}/.gitolite.rc"] ],
    }

    if $git_daemon {
      if $git_vhost == 'absent' {
        fail("You need to define \$git_vhost if you want to git_daemon for ${name}")
      }
      file{"/var/lib/git/${git_vhost}":
        ensure  => link,
        target  => "${real_basedir}/repositories",
        require => Exec["create_gitolite_${name}"],
      }
    }

  } else {
    User::Groups::Manage_user[$name]{
      before => User::Managed[$name],
    }
  }
}
