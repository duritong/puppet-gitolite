class gitolite::daemon::selinux {

  selboolean{'git_system_enable_homedirs':
    value       => 'on',
    persistent  => true,
    require     => Package['git-daemon'],
    before      => Service['xinetd'],
  }

  selinux::fcontext{'/home/[^/]*/repositories(/.*)?':
    setype => 'git_system_content_t',
    require   => Package['git-daemon'],
    before    => Service['xinetd'],
  }

  selinux::policy{
    'git_daemon_gitolite':
      te_source => 'puppet:///modules/gitolite/selinux/daemon/git_daemon_gitolite.te',
      require   => Package['git-daemon'],
      before    => Service['xinetd'],
  }

}
