#!/bin/bash

# Check if we are root
if [ "$(id -u)" -ne 0 ]; then
	echo 'You should run this installation script as root!'
	exit 1
fi

TIMESTAMP=`date '+%Y%m%d%H%M%S'`
backupFile() {
	[ -f "$1" ] && [ ! -f "$1".old$TIMESTAMP ] && cp -p "$1" "$1".old$TIMESTAMP
}

# Reduce disk IO
# Disable swap
echo 'Disable swap'
swapoff -a
dphys-swapfile swapoff
dphys-swapfile uninstall
systemctl -q is-enabled dphys-swapfile &&
	systemctl disable dphys-swapfile

# Limit logging
#backupFile /etc/logrotate.conf
#sed 's|^weekly$|daily|' -i /etc/logrotate.conf
#sed 's|^rotate .*$|rotate 0|' -i /etc/logrotate.conf

# Mount /boot read only
if grep -q '^\S*\s*\/boot\s*\S*\s*defaults\s' /etc/fstab; then
	backupFile /etc/fstab
	sed 's|^\(\S*\s*/boot\s*\S*\s*\)defaults\s\{1,4\}|\1defaults,ro |' -i /etc/fstab
	#mount -o remount /boot
fi

# Create some more tmpfs mount points

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
