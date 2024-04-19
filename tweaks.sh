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

# Pin Launchpad PPA
cat << 'EOF' > /etc/apt/preferences.d/ubuntu-rockchip-ppas
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

# All users must be part of the video group for hw acceleration
cat << 'EOF' > /etc/adduser.conf
# /etc/adduser.conf: `adduser' configuration.
# See adduser(8) and adduser.conf(5) for full documentation.

# The DSHELL variable specifies the default login shell on your
# system.
DSHELL=/bin/bash

# The DHOME variable specifies the directory containing users' home
# directories.
DHOME=/home

# If GROUPHOMES is "yes", then the home directories will be created as
# /home/groupname/user.
GROUPHOMES=no

# If LETTERHOMES is "yes", then the created home directories will have
# an extra directory - the first letter of the user name. For example:
# /home/u/user.
LETTERHOMES=no

# The SKEL variable specifies the directory containing "skeletal" user
# files; in other words, files such as a sample .profile that will be
# copied to the new user's home directory when it is created.
SKEL=/etc/skel

# FIRST_SYSTEM_[GU]ID to LAST_SYSTEM_[GU]ID inclusive is the range for UIDs
# for dynamically allocated administrative and system accounts/groups.
# Please note that system software, such as the users allocated by the base-passwd
# package, may assume that UIDs less than 100 are unallocated.
FIRST_SYSTEM_UID=100
LAST_SYSTEM_UID=999

FIRST_SYSTEM_GID=100
LAST_SYSTEM_GID=999

# FIRST_[GU]ID to LAST_[GU]ID inclusive is the range of UIDs of dynamically
# allocated user accounts/groups.
FIRST_UID=1000
LAST_UID=59999

FIRST_GID=1000
LAST_GID=59999

# The USERGROUPS variable can be either "yes" or "no".  If "yes" each
# created user will be given their own group to use as a default.  If
# "no", each created user will be placed in the group whose gid is
# USERS_GID (see below).
USERGROUPS=yes

# If USERGROUPS is "no", then USERS_GID should be the GID of the group
# `users' (or the equivalent group) on your system.
USERS_GID=100

# If DIR_MODE is set, directories will be created with the specified
# mode. Otherwise the default mode 0755 will be used.
DIR_MODE=0750

# If SETGID_HOME is "yes" home directories for users with their own
# group the setgid bit will be set. This was the default for
# versions << 3.13 of adduser. Because it has some bad side effects we
# no longer do this per default. If you want it nevertheless you can
# still set it here.
SETGID_HOME=no

# If QUOTAUSER is set, a default quota will be set from that user with
# `edquota -p QUOTAUSER newuser'
QUOTAUSER=""

# If SKEL_IGNORE_REGEX is set, adduser will ignore files matching this
# regular expression when creating a new home directory
SKEL_IGNORE_REGEX="dpkg-(old|new|dist|save)"

# Set this if you want the --add_extra_groups option to adduser to add
# new users to other groups.
# This is the list of groups that new non-system users will be added to
# Default:
EXTRA_GROUPS="video"

# If ADD_EXTRA_GROUPS is set to something non-zero, the EXTRA_GROUPS
# option above will be default behavior for adding new, non-system users
ADD_EXTRA_GROUPS=1


# check user and group names also against this regular expression.
#NAME_REGEX="^[a-z][-a-z0-9_]*\$"

# use extrausers by default
#USE_EXTRAUSERS=1
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

add-apt-repository -y ppa:jjriek/panfork-mesa
add-apt-repository -y ppa:jjriek/rockchip-multimedia
add-apt-repository -y ppa:jjriek/rockchip

# Grab the launchpad key
curl -S "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3CC0D9D1F3F0354B50D24F51F02122ECF25FB4D7" | gpg --batch --yes --dearmor --output /etc/apt/trusted.gpg.d/launchpad-jjriek.gpg

apt-get -y purge flash-kernel fwupd 

update-initramfs -u
u-boot-update

rm -- "$0"
