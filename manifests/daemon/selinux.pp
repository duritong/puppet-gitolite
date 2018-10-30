# selinux specific options needed for a daemon
class gitolite::daemon::selinux {
  include ::gitolite
  include ::gitolite::base
  selboolean{'git_system_enable_homedirs':
    value       => 'on',
    persistent  => true,
    require     => Package['git-daemon'],
  } -> selinux::policy{
    'git_daemon_gitolite':
      te_source => 'puppet:///modules/gitolite/selinux/daemon/git_daemon_gitolite.te',
  } -> selinux::fcontext{'/home/[^/]+/repositories(/.*)?':
    setype => $gitolite::base::setype,
  } -> Service<| title == 'xinetd' or title == 'git.socket' |>
}
