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
    require     => Package['dropbear'],
    notify      => Exec['update initramfs'],
    refreshonly => true;
  }

  exec { 'reuse ecdsa host key':
    command     => 'dropbearconvert openssh dropbear /etc/ssh/ssh_host_ecdsa_key /etc/initramfs-tools/etc/dropbear/dropbear_ecdsa_host_key',
    path        => '/usr/lib/dropbear/',
    require     => Package['dropbear'],
    notify      => Exec['update initramfs'],
    refreshonly => true;
  }

  exec { 'reuse rsa host key':
    command     => 'dropbearconvert openssh dropbear /etc/ssh/ssh_host_rsa_key /etc/initramfs-tools/etc/dropbear/dropbear_rsa_host_key',
    path        => '/usr/lib/dropbear/',
    require     => Package['dropbear'],
    notify      => Exec['update initramfs'],
    refreshonly => true;
  }

  file { '/etc/initramfs-tools/root/.ssh':
    ensure  => directory,
    recurse => true,
    purge   => true,
    owner   => root,
    group   => root,
    mode    => '0700',
    notify  => File['/etc/initramfs-tools/root/.ssh/authorized_keys'];
  }

  file { '/etc/initramfs-tools/root/.ssh/authorized_keys':
    ensure  => file,
    source  => "file:///home/${::ownerid}/.ssh/authorized_keys",
    owner   => root,
    group   => root,
    mode    => '0600',
    require => File['/etc/initramfs-tools/root/.ssh'],
    notify  => Exec['update initramfs'];
  }

  file { '/etc/initramfs-tools/hooks/crypt_unlock.sh':
    ensure => file,
    source => 'puppet:///modules/luks/crypt_unlock.sh',
    owner  => root,
    group  => root,
    mode   => '0700',
    notify => Exec['update initramfs'];
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
    require     => [  Exec['reuse dsa host key'],
                      Exec['reuse ecdsa host key'],
                      Exec['reuse rsa host key'],
                      Service['dropbear'],
                      File['/etc/initramfs-tools/root/.ssh/authorized_keys'],
                      File['/etc/initramfs-tools/hooks/crypt_unlock.sh'],
                      Augeas['initramfs.conf - add hostname'] ],
    refreshonly => true;
  }
}
