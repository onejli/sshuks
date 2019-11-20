class luks {

  if ! $::ownerid {
    fail ('Cannot proceed because \'ownerid\' fact is not defined.')
  }

  package { 'dropbear':
    ensure   => installed,
    notify   => [ Service['dropbear'],
                  Exec['generate ecdsa host key'],
                  Exec['generate rsa host key'] ];
  }

  service { 'dropbear':
    ensure   => stopped,
    enable   => false,
    require  => Package['dropbear'];
  }

  $initramfs_dropbear_dirs = [ '/etc/initramfs-tools/etc', '/etc/initramfs-tools/etc/dropbear' ]
  file { $initramfs_dropbear_dirs:
    ensure   => directory,
    owner    => root,
    group    => root,
    mode     => '0755';
  }

  # even though dropbear-run.postinst converts+reuses existing OpenSSH host keys, let's generate a fresh set
  exec { 'generate ecdsa host key':
    command  => 'dropbearkey -t ecdsa -s 384 -f /etc/initramfs-tools/etc/dropbear/dropbear_ecdsa_host_key',
    path     => '/usr/bin/',
    require  => [ Package['dropbear'],
                  File['/etc/initramfs-tools/etc/dropbear'] ],
    creates  => '/etc/initramfs-tools/etc/dropbear/dropbear_ecdsa_host_key',
    notify   => Exec['update initramfs'];
  }

  exec { 'generate rsa host key':
    command  => 'dropbearkey -t rsa -s 4096 -f /etc/initramfs-tools/etc/dropbear/dropbear_rsa_host_key',
    path     => '/usr/bin/',
    require  => [ Package['dropbear'],
                  File['/etc/initramfs-tools/etc/dropbear'] ],
    creates  => '/etc/initramfs-tools/etc/dropbear/dropbear_rsa_host_key',
    notify   => Exec['update initramfs'];
  }

  $dotssh_dirs = [ '/etc/initramfs-tools/root', '/etc/initramfs-tools/root/.ssh' ]
  file { $dotssh_dirs:
    ensure   => directory,
    owner    => root,
    group    => root,
    mode     => '0700',
    notify   => File['/etc/initramfs-tools/root/.ssh/authorized_keys'];
  }

  file { '/etc/initramfs-tools/root/.ssh/authorized_keys':
    ensure   => file,
    source   => "file:///home/${::ownerid}/.ssh/authorized_keys",
    owner    => root,
    group    => root,
    mode     => '0600',
    require  => File['/etc/initramfs-tools/root/.ssh'],
    notify   => Exec['update initramfs'];
  }

  file { '/etc/initramfs-tools/hooks/crypt_unlock.sh':
    ensure   => file,
    source   => 'puppet:///modules/luks/crypt_unlock.sh',
    owner    => root,
    group    => root,
    mode     => '0700',
    notify   => Exec['update initramfs'];
  }

  # https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt
  augeas { 'initramfs.conf - add hostname':
    context   => '/files/etc/initramfs-tools/initramfs.conf',
    incl      => '/etc/initramfs-tools/initramfs.conf',
    lens      => 'simplevars.lns',
    changes   => ["set IP ::::${::hostname}::dhcp"],
    notify    => Exec['update initramfs'];
  }

  augeas { 'initramfs.conf - dropbear options':
    context   => '/files/etc/initramfs-tools/initramfs.conf',
    incl      => '/etc/initramfs-tools/initramfs.conf',
    lens      => 'simplevars.lns',
    changes   => ["set DROPBEAR_OPTIONS '\"-p 8022 -j -k -I 60\"'"],
    notify    => Exec['update initramfs'];
  }

  exec { 'update initramfs':
    command      => 'update-initramfs -u',
    path         => [ '/bin', '/usr/bin', '/usr/sbin' ],
    require      => [ Exec['generate ecdsa host key'],
                      Exec['generate rsa host key'],
                      Service['dropbear'],
                      File['/etc/initramfs-tools/root/.ssh/authorized_keys'],
                      File['/etc/initramfs-tools/hooks/crypt_unlock.sh'],
                      Augeas['initramfs.conf - add hostname'],
                      Augeas['initramfs.conf - dropbear options'] ],
    refreshonly  => true;
  }
}
