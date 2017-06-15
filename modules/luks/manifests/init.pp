class luks {

  if ! $::ownerid {
    fail ('Cannot proceed because \'ownerid\' fact is not defined.')
  }

  package { 'dropbear':
    ensure => installed,
    notify => [ Service['dropbear'],
                Exec['reuse dsa host key'],
                Exec['reuse ecdsa host key'],
                Exec['reuse rsa host key'] ];
  }

  service { 'dropbear':
    ensure  => stopped,
    enable  => false,
    require => Package['dropbear'];
  }

  exec { 'reuse dsa host key':
    command     => 'dropbearconvert openssh dropbear /etc/ssh/ssh_host_dsa_key /etc/initramfs-tools/etc/dropbear/dropbear_dss_host_key',
    path        => '/usr/lib/dropbear/',
    require     => Service['dropbear'],
    refreshonly => true;
  }

  exec { 'reuse ecdsa host key':
    command     => 'dropbearconvert openssh dropbear /etc/ssh/ssh_host_ecdsa_key /etc/initramfs-tools/etc/dropbear/dropbear_ecdsa_host_key',
    path        => '/usr/lib/dropbear/',
    require     => Service['dropbear'],
    refreshonly => true;
  }

  exec { 'reuse rsa host key':
    command     => 'dropbearconvert openssh dropbear /etc/ssh/ssh_host_rsa_key /etc/initramfs-tools/etc/dropbear/dropbear_rsa_host_key',
    path        => '/usr/lib/dropbear/',
    require     => Service['dropbear'],
    refreshonly => true;
  }

  file { '/etc/initramfs-tools/root/.ssh':
    ensure  => directory,
    recurse => true,
    purge   => true,
    owner   => root,
    group   => root,
    mode    => '0700',
    require => Package['dropbear'],
    notify  => File['/etc/initramfs-tools/root/.ssh/authorized_keys'];
  }

  file { '/etc/initramfs-tools/root/.ssh/authorized_keys':
    ensure  => file,
    # TODO: this assumes that facter has an ownerid fact...
    source  => "file:///home/${::ownerid}/.ssh/authorized_keys",
    owner   => root,
    group   => root,
    mode    => '0600',
    require => File['/etc/initramfs-tools/root/.ssh'];
  }

  file { '/etc/initramfs-tools/hooks/crypt_unlock.sh':
    ensure  => file,
    source  => 'puppet:///modules/luks/crypt_unlock.sh',
    owner   => root,
    group   => root,
    mode    => '0700',
    require => Package['dropbear'];
  }

  augeas { 'initramfs.conf - add hostname':
    context => '/files/etc/initramfs-tools/initramfs.conf',
    incl    => '/etc/initramfs-tools/initramfs.conf',
    lens    => 'shellvars.lns',
    changes => ["set IP ::::${::hostname}::dhcp"],
    notify  => Exec['update initramfs'];
  }

  exec { 'update initramfs':
    command     => 'update-initramfs -u',
    path        => [ '/bin', '/usr/bin', '/usr/sbin' ],
    refreshonly => true;
  }
}
