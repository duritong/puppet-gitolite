# with web including (like cgit) we need to handle a few things differently
class gitolite::daemon::selinux::web inherits gitolite::daemon::selinux {
  Selinux::Fcontext['/home/[^/]+/repositories(/.*)?']{
    setype => 'httpd_git_rw_content_t',
  }
  selinux::fcontext{
    [ '/home/[^/]+/\.gitolite\.rc',
      '/home/[^/]+/\.gitolite(/.*)?',
      '/home/[^/]+/projects\.list' ]:
        setype => 'httpd_git_rw_content_t';
  }
}
