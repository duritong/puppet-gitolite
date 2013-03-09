# setup git-daemin for gitolite
class gitolite::daemon(
  $use_shorewall = false
) {
  class{'git::daemon':
    use_shorewall => $use_shorewall,
  }
  include xinetd

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
    before        => Augeas['enable_git_daemon'],
  }
  # clean dangling links
  file{'/var/lib/git':
    ensure        => directory,
    seltype       => 'git_system_content_t',
    owner         => root,
    group         => 0,
    mode          => '0644',
    recurse       => true,
    purge         => true,
    force         => true,
    recurselimit  => 1,
    require       => Package['git-daemon'],
  }
  augeas{'enable_git_daemon':
    context => '/files/etc/xinetd.d/git/service',
    changes => [
      'set disable no',
      'set user gitolited',
      'set server_args/value \'--interpolated-path=/var/lib/git/%H/%D --syslog --inetd\'',
    ],
    notify  => Service['xinetd'],
  }
}
