# central group for which ssh access
# can be allowed
class gitolite::gitaccess {
  group{'gitaccess':
    ensure => present
  }
}

