# sshuks (aka SSH + LUKS)
Unlocking a LUKS encrypted partition over SSH with Dropbear

Requirements
---------------
1. OpenSSH server and an SSH client configured for public key authentication

    i.e., You **MUST** have a client from which you can ssh into the server **WITHOUT** being prompted for a password.
    ```
    user@client:~$ ssh server
    Last login: Thu Jun 15 11:43:58 2017 from 127.0.0.1
    user@server:~$
    ```
2. Puppet
3. Facter `ownerid` fact that maps to the user whose `~/.ssh/authorized_keys` file will be used

    i.e., This command should return something sensible.
    ```
    user@server:~$ /usr/bin/sudo $(which facter) -p ownerid
    jonathan.li
    ````

Getting Started
---------------
1. Clone this repository onto the server that needs to be remotely unlocked
2. Invoke a masterless puppet run
    ```
    /usr/bin/sudo $(which puppet) apply --modulepath sshuks/modules/ sshuks/manifests/site.pp --verbose --test
    ```
    Optionally include `--noop` to see ["what changes Puppet will make without actually executing the changes."](https://docs.puppet.com/puppet/latest/man/apply.html#OPTIONS)
3. Reboot the host **IF** the puppet run was **SUCCESSFUL**
4. Connect to the Dropbear SSH server and unlock the LUKS encrypted partition

    1. ssh as the **root** user on port 8022 (i.e., `ssh -p 8022 root@<HOSTNAME_GOES_HERE>`)
    2. Execute the `unlock` command
    3. Input your unlock password
    ```
    user@client:~$ ssh -p 8022 root@<HOSTNAME_GOES_HERE>
    To unlock root-partition run unlock


    BusyBox v1.22.1 (Ubuntu 1:1.22.0-15ubuntu1) built-in shell (ash)
    Enter 'help' for a list of built-in commands.

    # unlock
    Please unlock disk sda5_crypt: <PASSWORD_GOES_HERE>
      /run/lvm/lvmetad.socket: connect failed: No such file or directory
      WARNING: Failed to connect to lvmetad. Falling back to internal scanning.
      Reading all physical volumes.  This may take a while...
      Found volume group "vgdata" using metadata type lvm2
      Found volume group "crypt" using metadata type lvm2
      /run/lvm/lvmetad.socket: connect failed: No such file or directory
      WARNING: Failed to connect to lvmetad. Falling back to internal scanning.
      1 logical volume(s) in volume group "vgdata" now active
      3 logical volume(s) in volume group "crypt" now active
    cryptsetup: sda5_crypt set up successfully
    Connection to <HOSTNAME_GOES_HERE> closed.
    ```

Additional Details
---------------
* By default, the `-Fs` flags are passed to Dropbear.  This module also includes `-p 8022 -j -k -I 60`.

    From the Dropbear man page:
    ```
    -F     Don't fork into background.
    -s     Disable password logins.
    -p [address:]port
           Listen on specified address and TCP port. If just a port is given listen on all
           addresses. up to 10 can be specified (default 22 if none specified).
    -j     Disable local port forwarding.
    -k     Disable remote port forwarding.
    -I idle_timeout
           Disconnect the session if no traffic is transmitted or received for idle_timeout seconds.
    ```
* The `/usr/share/initramfs-tools/scripts/init-premount/dropbear` script is used to start the Dropbear SSH server.
    ```bash
    #!/bin/sh

    PREREQ="udev"

    prereqs() {
        echo "$PREREQ"
    }

    case "$1" in
        prereqs)
            prereqs
            exit 0
        ;;
    esac

    [ "$IP" != off -a "$IP" != none -a -x /sbin/dropbear ] || exit 0


    run_dropbear() {
        # always run configure_networking() before dropbear(8); on NFS
        # mounts this has been done already
        [ "$boot" = nfs ] || configure_networking

        log_begin_msg "Starting dropbear"
        # using exec and keeping dropbear in the foreground enables the
        # init-bottom script to kill the remaining ipconfig processes if
        # someone unlocks the rootfs from the console while the network is
        # being configured
        exec /sbin/dropbear ${DROPBEAR_OPTIONS:-$PKGOPTION_dropbear_OPTION} -Fs
    }

    . /conf/initramfs.conf
    . /scripts/functions

    # On NFS mounts, wait until the network is configured.  On local mounts,
    # configure the network in the background (in run_dropbear()) so someone
    # with console access can enter the passphrase immediately.  (With the
    # default ip=dhcp, configure_networking hangs for 5mins or so when the
    # network is unavailable, for instance.)
    [ "$boot" != nfs ] || configure_networking

    run_dropbear &
    echo $! >/run/dropbear.pid
    ```

References
---------------
* https://stinkyparkia.wordpress.com/2014/10/14/remote-unlocking-luks-encrypted-lvm-using-dropbear-ssh-in-ubuntu-server-14-04-1-with-static-ipst
* https://hamy.io/post/0009/how-to-install-luks-encrypted-ubuntu-18.04.x-server-and-enable-remote-unlocking/
