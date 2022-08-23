#!/bin/bash
#
# Reduce disk IO to increase SD card lifetime on Raspberry Pi
#
# By Rogier van Staveren
# https://github.com/rrooggiieerr/raspi-utils/
#

echo 'This script will reduce the disk IO by disabling swap, limit log file rotation
and configuring tmpfs mount points.
'

# Check if we are root
if [ "$(id -u)" -ne 0 ]; then
	echo 'You should run this configuration script as root!'
	exit 1
else
	read -p 'Press Ctrl-C to quit or any other key to continue.' -n 1
	echo
fi

TIMESTAMP=`date '+%Y%m%d%H%M%S'`
backupFile() {
	[ -f "$1" ] && [ ! -f "$1".old$TIMESTAMP ] && cp -p "$1" "$1".old$TIMESTAMP
}

# Reduce disk IO
# Disable swap
echo 'Disabling swap...'
swapoff -a
dphys-swapfile swapoff
dphys-swapfile uninstall
systemctl -q is-enabled dphys-swapfile &&
	systemctl disable dphys-swapfile

# Limit log file rotation
if grep -q '^weekly$' /etc/logrotate.conf || ! grep -q '^rotate 1' /etc/logrotate.conf; then
	echo 'Limiting log file rotation...'
	backupFile /etc/logrotate.conf
	sed 's|^weekly$|daily|' -i /etc/logrotate.conf
	sed 's|^rotate .*$|rotate 1|' -i /etc/logrotate.conf
fi

# Mount /boot read only
if grep -q '^\S*\s*\/boot\s*\S*\s*\S*\s' /etc/fstab; then
	echo 'Mounting /boot read only...'
	backupFile /etc/fstab
	sed 's|^\(\S*\s*/boot\s*\S*\s*\S*\)\s\{1,4\}|\1,ro |' -i /etc/fstab
	#mount -o remount /boot
fi

# Create some more tmpfs mount points
echo 'Creating tmpfs mount points...'
if ! grep -q '^\S*\s*\/tmp\s' /etc/fstab; then
	backupFile /etc/fstab
	echo 'tmpfs           /tmp            tmpfs   nosuid,nodev      0       0' >> /etc/fstab
	rm -r /tmp/* /tmp/.* 2> /dev/null
	mount /tmp
fi
if ! grep -q '^\S*\s*\/var\/tmp\s' /etc/fstab; then
	backupFile /etc/fstab
	echo 'tmpfs           /var/tmp        tmpfs   nosuid,nodev      0       0' >> /etc/fstab
	rm -r /var/tmp/* /var/tmp/.* 2> /dev/null
	mount /var/tmp
fi
if ! grep -q '^\S*\s*\/var\/log\s' /etc/fstab; then
	backupFile /etc/fstab
	echo 'tmpfs           /var/log        tmpfs   defaults,noatime,nosuid,mode=0755,size=100m  0       0' >> /etc/fstab
	systemctl stop rsyslog
	rm -r /var/log/*
	mount /var/log
	systemctl start rsyslog
fi

echo
echo 'Disk IO has been reduced'
