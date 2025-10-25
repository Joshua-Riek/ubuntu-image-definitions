#!/bin/bash

# Do not let systemd handle resolv.conf
rm -rf /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Update localisation files
locale-gen en_US.UTF-8
update-locale LANG="en_US.UTF-8"

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

# Disable apparmor
systemctl mask apparmor

# Disable motd news
if [ -f /etc/default/motd-news ]; then
    sed -i 's/ENABLED=1/ENABLED=0/g' /etc/default/motd-news
fi

# Add new users to the video group
sed -i 's/#EXTRA_GROUPS=.*/EXTRA_GROUPS="video"/g' /etc/adduser.conf
sed -i 's/#ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/g' /etc/adduser.conf

# Grab launchpad key
curl -S "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3CC0D9D1F3F0354B50D24F51F02122ECF25FB4D7" | gpg --batch --yes --dearmor --output "/etc/apt/trusted.gpg.d/launchpad-jjriek.gpg"

# shellcheck source=/dev/null
source /etc/os-release

if [ "$VERSION_ID" == "24.04" ] || [ "$VERSION_ID" == "22.04" ]; then
    # Pin rockchip package archives
    (
        echo "Package: *"
        echo "Pin: release o=LP-PPA-jjriek-rockchip"
        echo "Pin-Priority: 1001"
        echo ""
        echo "Package: *"
        echo "Pin: release o=LP-PPA-jjriek-rockchip-multimedia"
        echo "Pin-Priority: 1001"
        echo ""
        echo "Package: *"
        echo "Pin: release o=LP-PPA-jjriek-panfork-mesa"
        echo "Pin-Priority: 1001"    
    ) > config/archives/extra-ppas.pref.chroot
fi

if [ "$VERSION_ID" == "24.04" ]; then
    # Ignore custom ubiquity package (mistake i made, uploaded to wrong ppa)
    (
        echo "Package: oem-*"
        echo "Pin: release o=LP-PPA-jjriek-rockchip-multimedia"
        echo "Pin-Priority: -1"
        echo ""
        echo "Package: ubiquity*"
        echo "Pin: release o=LP-PPA-jjriek-rockchip-multimedia"
        echo "Pin-Priority: -1"

    ) > config/archives/extra-ppas-ignore.pref.chroot
fi

# Override u-boot-menu config  
mkdir -p /usr/share/u-boot-menu/conf.d
cat << 'EOF' > /usr/share/u-boot-menu/conf.d/ubuntu.conf
U_BOOT_PROMPT="1"
U_BOOT_PARAMETERS="$(cat /etc/kernel/cmdline)"
U_BOOT_TIMEOUT="20"
EOF

# Default kernel command line arguments
echo -n "rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" > /etc/kernel/cmdline

if dpkg -s oem-config &>/dev/null; then
    # The cloud-init will not allow for user groups to be assigned on the first login
    apt-get -y purge cloud-init

    # Prepare required oem installer paths 
    mkdir -p /var/log/installer
    touch /var/log/installer/debug
    touch /var/log/syslog
    chown syslog:adm /var/log/syslog
        # Create the oem user account only if it doesn't already exist
    if ! id "oem" &>/dev/null; then
        /usr/sbin/useradd -d /home/oem -G adm,sudo,video -m -N -u 29999 oem
        /usr/sbin/oem-config-prepare --quiet
        touch "/var/lib/oem-config/run"
    fi
    
    # Create host ssh keys
    ssh-keygen -A

    # Enable wayland session
    sed -i 's/#WaylandEnable=false/WaylandEnable=true/g' /etc/gdm3/custom.conf

    # Adjust kernel command line arguments for desktop
    echo -n " quiet splash plymouth.ignore-serial-consoles" >> /etc/kernel/cmdline
fi

# Download and update installed packages
apt-get update
apt-get upgrade --allow-downgrades --assume-yes
apt-get dist-upgrade --allow-downgrades --assume-yes

apt-get -y purge flash-kernel fwupd 

# Clean package cache
apt-get autoremove --assume-yes
apt-get clean --assume-yes
apt-get autoclean --assume-yes

# Make sure the initramfs is up to date
update-initramfs -u

# Update extlinux
u-boot-update

rm -- "$0"
