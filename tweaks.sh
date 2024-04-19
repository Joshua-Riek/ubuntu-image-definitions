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

# Pin Launchpad PPA
cat << EOF > /etc/apt/preferences.d/ubuntu-rockchip-ppas
Package: *
Pin: release o=LP-PPA-jjriek-rockchip
Pin-Priority: 1001

Package: *
Pin: release o=LP-PPA-jjriek-rockchip-multimedia
Pin-Priority: 1001

Package: *
Pin: release o=LP-PPA-jjriek-panfork-mesa
Pin-Priority: 1001
EOF

# Override u-boot-menu config  
mkdir -p /usr/share/u-boot-menu/conf.d
cat << 'EOF' > /usr/share/u-boot-menu/conf.d/ubuntu.conf
U_BOOT_PROMPT="1"
U_BOOT_PARAMETERS="$(cat /etc/kernel/cmdline)"
U_BOOT_TIMEOUT="10"
EOF

# Default kernel command line arguments
echo -n "rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" > /etc/kernel/cmdline

if dpkg -s oem-config; then
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

# Grab the launchpad key
curl -S "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3CC0D9D1F3F0354B50D24F51F02122ECF25FB4D7" | gpg --batch --yes --dearmor --output /etc/apt/trusted.gpg.d/launchpad-jjriek.gpg

apt-get -y purge flash-kernel fwupd 

update-initramfs -u
u-boot-update

rm -- "$0"
