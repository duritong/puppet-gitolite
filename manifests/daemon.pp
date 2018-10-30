# setup git-daemin for gitolite
class gitolite::daemon(
  $use_shorewall = false
) {
  class{'git::daemon':
    use_shorewall => $use_shorewall,
  }
  if versioncmp($facts['os']['release']['major'],'7') >= 0 {
    systemd::unit_file{
      'git@.service':
        source => 'puppet:///modules/gitolite/daemon/git@.service',
    } -> service{'git.socket':
      ensure => running,
      enable => true,
    }
  } else {
    include xinetd
    augeas{'enable_git_daemon':
      context => '/files/etc/xinetd.d/git/service',
      changes => [
        'set disable no',
        'set user gitolited',
        'rm server_args/value',
        'set server_args/value[1] --interpolated-path=/var/lib/git/%H/%D',
        'set server_args/value[2] --syslog',
        'set server_args/value[3] --inetd',
      ],
      notify  => Service['xinetd'],
      require => User::Managed['gitolited'],
    }
  }

  $shell = $::operatingsystem ? {
    debian  => '/usr/sbin/nologin',
    ubuntu  => '/usr/sbin/nologin',
    default => '/sbin/nologin'
  }
  user::managed{'gitolited':
    name_comment  => 'gitolited git-daemon user',
    managehome    => false,
    homedir       => '/var/lib/git',
    shell         => $shell,
    require       => Package['git-daemon'],
  }
  # clean dangling links
  file{'/var/lib/git':
    ensure        => directory,
    seltype       => 'git_sys_content_t',
    owner         => root,
    group         => 0,
    mode          => '0644',
    recurse       => true,
    purge         => true,
    force         => true,
    recurselimit  => 1,
    require       => Package['git-daemon'],
  }

  if str2bool($facts['selinux']) {
    include gitolite::daemon::selinux
  }
}
