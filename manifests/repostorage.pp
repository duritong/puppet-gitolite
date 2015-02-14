# a gitloite repostorage
define gitolite::repostorage(
  $ensure              = 'present',
  $configuration       = {},
  $initial_admin       = 'absent',
  $initial_sshkey      = 'absent',
  $password            = 'absent',
  $password_crypted    = true,
  $uid                 = 'absent',
  $gid                 = 'uid',
  $manage_user_group   = true,
  $basedir             = 'absent',
  $disk_size           = false,
  $allowdupe_user      = false,
  $rc_options          = {},
  $git_daemon          = false,
  $git_vhost           = 'absent',
  $cgit                = false,
  $anonymous_http      = false,
  $ssl_mode            = 'normal',
  $domainalias         = 'absent',
  $domainalias_postfix = 'absent',
  $domainalias_prefix  = 'git-',
  $cgit_options        = {},
  $nagios_check        = false,
  $nagios_web_check    = 'OK',
  $nagios_web_use      = 'generic-service'
){

  # params validation
  if ($ensure == 'present') and (
    ($initial_sshkey == 'absent') or ($initial_admin == 'absent')) {
    fail("\$initial_sshkey must be set if ${name} should be present!")
  }
  if ($ensure == 'present') and ($cgit and $git_vhost == 'absent') {
    fail("You need to pass \$git_vhost if you want to use cgit for ${name}!")
  }
  if ($ensure == 'present') and ($git_daemon and $git_vhost == 'absent') {
    fail("\$git_vhost must be present if using git_daemon for ${name}!")
  }
  if ($ensure == 'present') and ($anonymous_http and !$cgit) {
    fail("Must enable \$cgit if you want to use anonymous_http for ${name}!")
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
    ensure           => $ensure,
    homedir          => $real_basedir,
    allowdupe        => $allowdupe_user,
    uid              => $real_uid,
    gid              => $real_gid,
    manage_group     => $manage_user_group,
    password         => $real_password,
    password_crypted => $password_crypted,
  }

  if $disk_size and $ensure == 'present' {
    disks::lv_mount{
      "git-${name}":
        size   => $disk_size,
        folder => $real_basedir,
        owner  => $real_uid,
        group  => $real_gid,
        mode   => '0750',
        before => User::Managed[$name],
    }
    User::Managed[$name] {
      managehome => false,
    }
  }

  include ::gitolite::gitaccess
  $gitolited_ensure = $ensure ? {
    'absent'  => 'absent',
    default   => $git_daemon ? {
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
      user   => 'gitolited',
      group  => $name;
  }

  if $ensure == 'present' {
    User::Groups::Manage_user[$name,"gitolited_in_${name}"]{
      require => [ Group['gitaccess'], User::Managed[$name] ],
    }

    if $git_daemon {
      $gitolite_umask = '0027'
    } else {
      $gitolite_umask = '0077'
    }
    if $cgit {
      $external_settings = {
        'site_info' =>
          "'Have a look at http://${git_vhost} for your cgit hosting.'",
      }
      $commands = [ 'help', 'desc', 'info', 'perms', 'writable', 'hooks',
        'htpasswd', ]
    } else {
      $external_settings = {}
      $commands = [ 'help', 'desc', 'info', 'perms', 'writable', 'hooks' ]
    }
    $default_rc = {
      umask                 => $gitolite_umask,
      git_config_keys       => [ # some sane defaults
        'gitweb.owner', 'gitweb.description', 'gitweb.category',
        'hooks.mailinglist', 'hooks.emailprefix', 'hooks.announcelist',
        'hooks.envelopesender', 'hooks.generatepatch',
      ],
      extra_git_config_keys => [],
      log_extra             => false, #privacy by default
      external_settings     => $external_settings,
      commands              => $commands,
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
      local_code            => '/opt/gitolite-local',
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
      require     => [ Package['gitolite'],
        File["${real_basedir}/${initial_admin}.pub",
              "${real_basedir}/.gitolite.rc"] ],
    }

    if $git_daemon {
      if $git_vhost == 'absent' {
        fail("\$git_vhost must be defined if using git_daemon for ${name}")
      }
      file{"/var/lib/git/${git_vhost}":
        ensure  => link,
        target  => "${real_basedir}/repositories",
        require => Exec["create_gitolite_${name}"],
      }
    }

    if $cgit {
      if $domainalias_postfix != 'absent' {
        if $domainalias != 'absent' {
          $real_domainalias = "${domainalias} \
${domainalias_prefix}${name}${domainalias_postfix}"
        } else {
          $real_domainalias = "${domainalias_prefix}${name}\
${domainalias_postfix}"
        }
      } else {
        $real_domainalias = $domainalias
      }

      cgit::instance{
        $git_vhost:
          ensure           => $ensure,
          configuration    => $configuration,
          domainalias      => $real_domainalias,
          base_dir         => $real_basedir,
          ssl_mode         => $ssl_mode,
          user             => $name,
          group            => $name,
          anonymous_http   => $anonymous_http,
          cgit_options     => $cgit_options,
          nagios_check     => $nagios_check,
          nagios_web_check => $nagios_web_check,
          nagios_web_use   => $nagios_web_use,
          require          => User::Managed[$name],
      }
    }

  } else {
    User::Groups::Manage_user[$name,"gitolited_in_${name}"]{
      before => User::Managed[$name],
    }
  }

  if ($ensure == 'present') and str2bool($::selinux) {
    exec{"restorecon_${name}":
      command     => "restorecon -R ${real_basedir}",
      refreshonly => true,
      subscribe   => Exec["create_gitolite_${name}"];
    }
  }

  if $nagios_check {
    $check_hostname = $git_vhost ? {
      'absent'  => $::fqdn,
      default   => $git_vhost
    }
    sshd::nagios{"gitrepo_${name}":
      ensure         => $ensure,
      port           => 22,
      check_hostname => $check_hostname,
    }
    $git_daemon_ensure = $ensure ? {
      'present' => $git_daemon ? {
        false   => 'absent',
        default => 'present'
      },
      default   => $ensure
    }
    nagios::service{"git_${name}":
      ensure        => $git_daemon_ensure,
      check_command => "check_git!${check_hostname}",
    }
  }
}
