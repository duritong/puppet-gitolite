# on centos we want to got with gitloite3
class gitolite::centos inherits gitolite::base {
  Package['gitolite']{
    name => 'gitolite3',
  }
}
