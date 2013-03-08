# gitolite packages and stuff
class gitolite::base {
  package{'gitolite':
    ensure => installed,
  }
}
