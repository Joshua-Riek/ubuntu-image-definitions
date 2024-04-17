#!/bin/bash

# Disable terminal ads
pro config set apt_news=false

# Disable apport bug reporting
sed -i 's/enabled=1/enabled=0/g' /etc/default/apport

# Remove release upgrade motd
rm -f /var/lib/ubuntu-release-upgrader/release-upgrade-available
sed -i 's/Prompt=.*/Prompt=never/g' /etc/update-manager/release-upgrades

# Let systemd create machine id on first boot
rm -f /var/lib/dbus/machine-id
true > /etc/machine-id 

# Disable grub
rm -rf /boot/grub

# Disable motd news
if [ -f /etc/default/motd-news ]; then
    sed -i 's/ENABLED=1/ENABLED=0/g' /etc/default/motd-news
fi

echo EXTRA_GROUPS=\"video\" >> /etc/adduser.conf
echo ADD_EXTRA_GROUPS=1 >>  /etc/adduser.conf

# Config for u-boot-menu
echo 'U_BOOT_PROMPT="1"' > /usr/share/u-boot-menu/conf.d/ubuntu.conf
echo 'U_BOOT_PARAMETERS="$(cat /etc/kernel/cmdline)"' >> /usr/share/u-boot-menu/conf.d/ubuntu.conf
echo 'U_BOOT_TIMEOUT="10"' >> /usr/share/u-boot-menu/conf.d/ubuntu.conf

# Default kernel command line arguments
echo -n "rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" > /etc/kernel/cmdline

if [ "$(dpkg -l | awk '/oem-config/ {print }'| wc -l)" -ge 1 ]; then
    mkdir -p /var/log/installer
    touch /var/log/installer/debug
    touch /var/log/syslog
    chown syslog:adm /var/log/syslog

    # Create the oem user account only if it doesn't already exist
    if ! id "oem" &>/dev/null; then
        /usr/sbin/useradd -d /home/oem -G adm,sudo -m -N -u 29999 oem
        /usr/sbin/oem-config-prepare --quiet
        touch "/var/lib/oem-config/run"
    fi

    # Enable wayland session
    sed -i 's/#WaylandEnable=false/WaylandEnable=true/g' /etc/gdm3/custom.conf

    # Adjust kernel command line arguments for desktop
    echo -n "quiet splash plymouth.ignore-serial-consoles" >> /etc/kernel/cmdline
fi

apt-get -y purge flash-kernel fwupd 
apt-get -y update
apt-get --allow-downgrades -y upgrade
apt-get --allow-downgrades -y dist-upgrade

rm -- "$0"
