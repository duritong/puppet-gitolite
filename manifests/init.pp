# basic requirements for gitolite
class gitolite {

  require git
  case $::operatingsystem {
    centos,redhat:  { include gitolite::centos }
    default:        { include gitolite::base }
  }
}
