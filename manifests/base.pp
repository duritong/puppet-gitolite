# gitolite packages and stuff
class gitolite::base {
  package{'gitolite':
    ensure => installed,
  } -> file{
    '/opt/gitolite-local':
      ensure  => directory,
      recurse => true,
      purge   => true,
      force   => true,
      owner   => root,
      group   => 0,
      mode    => '0755';
  }

  file{
    '/opt/gitolite-local/commands':
      ensure  => directory,
      source  => 'puppet:///modules/gitolite/commands/',
      recurse => true,
      purge   => true,
      force   => true,
      owner   => root,
      group   => 0,
      mode    => '0755';
    '/opt/git-hooks':
      ensure  => directory,
      source  => 'puppet:///modules/gitolite/hooks',
      recurse => true,
      purge   => true,
      force   => true,
      owner   => root,
      group   => 0,
      mode    => '0755';
  }

  if str2bool($::selinux) {
    if versioncmp($facts['os']['release']['major'],'7') >= 0 {
      $setype = 'git_content_t'
    } else {
      $setype = 'httpd_git_rw_content_t'
    }

    File['/opt/git-hooks']{
      seltype => 'bin_t',
    }
    selinux::fcontext{
      '/opt/git-hooks(/.*)?':
        setype => 'bin_t';
      '/home/[^/]+/git_tmp(/.*)?':
        setype => $setype,
    }
  }
}
