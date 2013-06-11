# anonymize ips in gitolite logs
class gitolite::anonymize {
  exec{'sed \'s/\$ENV{SSH_CONNECTION} || //\' /usr/share/gitolite3/gitolite-shell':
    unless  => 'grep -q \'$ip = $ENV{SSH_CONNECTION} ||\' /usr/share/gitolite3/gitolite-shell',
    require => Package['gitolite'],
  }
}
