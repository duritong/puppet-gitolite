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
  $domainalias_prefix  = 'git-',
  $domainalias_suffix  = 'absent',
  $cgit_options        = {},
  $cgit_clone_prefixes = undef,
  $nagios_check        = false,
  $nagios_check_code   = 'OK',
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

  if $disk_size {
    disks::lv_mount{
      "git-${name}":
        ensure => $ensure,
        size   => $disk_size,
        folder => $real_basedir,
    }
    if $ensure == 'present' {
      Disks::Lv_mount["git-${name}"]{
        owner  => $real_uid,
        group  => $real_gid,
        mode   => '0750',
        before => User::Managed[$name],
      }
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
  $cgit_ensure = $cgit ? {
    true  => $ensure,
    false => 'absent',
  }
  cgit::instance{
    $git_vhost:
      ensure            => $cgit_ensure,
      ssl_mode          => $ssl_mode,
      nagios_check      => $nagios_check,
      nagios_check_code => $nagios_check_code,
      nagios_web_use    => $nagios_web_use,
      base_dir          => $real_basedir,
  }

  if $ensure == 'present' {
    include ::gitolite
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

    if $initial_sshkey =~ /\n$/ {
      $pubkey = $initial_sshkey
    } else {
      $pubkey = "${initial_sshkey}\n"
    }
    if versioncmp($facts['os']['release']['major'],'7') >= 0 {
      $rc_seltype = 'git_content_t'
    } else {
      $rc_seltype = 'httpd_git_rw_content_t'
    }
    file{
      "${real_basedir}/${initial_admin}.pub":
        content => $pubkey,
        owner   => $name,
        group   => $name,
        mode    => '0600';
      "${real_basedir}/.gitolite.rc":
        content => template('gitolite/gitolite.rc.erb'),
        owner   => $name,
        group   => $name,
        mode    => '0600',
        seluser => 'system_u',
        seltype => $rc_seltype;
      "${real_basedir}/git_tmp":
        ensure  => directory,
        owner   => $name,
        group   => $name,
        seluser => 'system_u',
        seltype => $gitolite::base::setype,
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
      if $domainalias_suffix != 'absent' {
        if $domainalias != 'absent' {
          $real_domainalias = "${domainalias} \
${domainalias_prefix}${name}${domainalias_suffix}"
        } else {
          $real_domainalias = "${domainalias_prefix}${name}\
${domainalias_suffix}"
        }
        if $cgit_clone_prefixes {
          $real_cgit_clone_prefixes = $cgit_clone_prefixes
        } else {
          if $ssl_mode == 'force' {
            $real_cgit_clone_prefixes = [
              "https://${domainalias_prefix}${name}${domainalias_suffix}",
              "git://${git_vhost}",
            ]
          } elsif $ssl_mode {
            $real_cgit_clone_prefixes = [
              "https://${domainalias_prefix}${name}${domainalias_suffix}",
              "http://${git_vhost}",
              "git://${git_vhost}",
            ]
          } else {
            $real_cgit_clone_prefixes = [
              "http://${git_vhost}",
              "git://${git_vhost}",
            ]
          }
        }
      } else {
        $real_domainalias = $domainalias
        $real_cgit_clone_prefixes = $cgit_clone_prefixes
      }

      Cgit::Instance[$git_vhost]{
        configuration    => $configuration,
        domainalias      => $real_domainalias,
        user             => $name,
        group            => $name,
        anonymous_http   => $anonymous_http,
        cgit_options     => $cgit_options,
        clone_prefixes   => $real_cgit_clone_prefixes,
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
      subscribe   => Exec["create_gitolite_${name}"],
      require     => Cgit::Instance[$git_vhost];
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
