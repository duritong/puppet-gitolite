# a gitloite repostorage
define gitolite::repostorage(
  $ensure             = 'present',
  $initial_admin      = 'absent',
  $initial_sshkey     = 'absent',
  $password           = 'absent',
  $password_crypted   = true,
  $uid                = 'absent',
  $gid                = 'uid',
  $group_name         = 'absent',
  $manage_user_group  = true,
  $basedir            = 'absent',
  $allowdupe_user     = false,
){

  if ($ensure == 'present') and (($initial_sshkey == 'absent') or ($initial_admin == 'absent')) {
    fail("You need to pass \$initial_sshkey and \$initial_admin if repostorage ${name} should be present!")
  }
  include ::gitolite

  $real_password = $password ? {
    'trocla'  => trocla("gitolite_${name}",'sha512crypt'),
    default   => $password
  }

  $real_group_name = $group_name ? {
    'absent' => $name,
    default => $group_name
  }

  $real_basedir = $basedir ? {
    'absent' => "/home/${name}",
    default => $basedir
  }

  $real_uid => $uid ? {
    'iuid'  => iuid($real_uid_name,'webhosting'),
    default => $uid
  }
  $real_gid => $gid ? {
    'iuid'  => iuid($real_uid_name,'webhosting'),
    default => $gid
  }

  user::managed{$name:
    ensure            => $ensure,
    homedir           => $real_basedir,
    allowdupe         => $allowdupe_user,
    uid               => $real_uid,
    gid               => $real_gid,
    manage_group      => $manage_user_group,
    password          => $real_password,
    password_crypted  => $password_crypted,
  }


  user::groups::manage_user{
    $name:
      ensure => $ensure,
      group  => 'gitaccess',
  }

  if $ensure == 'present' {
    User::Groups::Manage_user[$name]{
      require => [ Group['gitaccess'], User::Managed[$name] ],
    }
    file{"${real_basedir}/initial_admin_pubkey.puppet":
      content => "${initial_sshkey}\n",
      require => User[$name],
      owner   => $name,
      group   => $real_group_name,
      mode    => '0600';
    }
    exec{"create_gitolite_${name}":
      command => "gitolite setup -pk ${real_basedir}/initial_admin_pubkey.puppet",
      unless  => "test -d ${real_basedir}/repositories",
      cwd     => $real_basedir,
      user    => $name,
      group   => $name,
      require => [ Package['gitolite'], File["${real_basedir}/initial_admin_pubkey.puppet"] ],
    }

  } else {
    User::Groups::Manage_user[$name]{
      before => User::Managed[$name],
    }
  }
}
