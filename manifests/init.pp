# basic requirements for gitolite
class gitolite {

  require git
  class $::operatingsystem {
    centos,redhat:  { include gitolite::centos }
    default:        { include gitolite::base }
  }
}
