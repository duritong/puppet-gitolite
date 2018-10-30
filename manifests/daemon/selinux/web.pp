# with web including (like cgit) we need to handle a few things differently
class gitolite::daemon::selinux::web {
  include ::gitolite::daemon::selinux
  selinux::fcontext{
    [ '/home/[^/]+/\.gitolite\.rc',
      '/home/[^/]+/\.gitolite(/.*)?',
      '/home/[^/]+/projects\.list.*' ]:
        setype => $gitolite::base::setype,
  }
}
