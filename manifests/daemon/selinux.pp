# selinux specific options needed for a daemon
class gitolite::daemon::selinux {
  include ::gitolite
  include ::gitolite::base
  if versioncmp($facts['os']['release']['major'],'7') >= 0 {
    $te_source = 'puppet:///modules/gitolite/selinux/daemon/git_daemon_gitolite.te'
  } else {
    $te_source = 'puppet:///modules/gitolite/selinux/daemon/git_daemon_gitolite.te.CentOS.6'
  }
  selboolean{'git_system_enable_homedirs':
    value       => 'on',
    persistent  => true,
    require     => Package['git-daemon'],
  } -> selinux::policy{
    'git_daemon_gitolite':
      te_source => $te_source,
  } -> selinux::fcontext{'/home/[^/]+/repositories(/.*)?':
    setype => $gitolite::base::setype,
  } -> Service<| title == 'xinetd' or title == 'git.socket' |>
}
