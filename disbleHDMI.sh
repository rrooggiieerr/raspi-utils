#!/bin/bash
#
# Disable Raspberry Pi HDMI port
#
# By Rogier van Staveren
# https://github.com/rrooggiieerr/raspi-utils/
#

echo 'This script will disable the HDMI port of your Raspberry Pi.
'

# Check if we are root
if [ "$(id -u)" -ne 0 ]; then
	echo 'You should run this installation script as root!'
	exit 1
else
	read -p 'Press Ctrl-C to quit or any other key to continue.' -n 1
	echo
fi

TIMESTAMP=`date '+%Y%m%d%H%M%S'`
backupFile() {
	[ -f "$1" ] && [ ! -f "$1.old$TIMESTAMP" ] && cp -p "$1" "$1.old$TIMESTAMP"
}

# Disable DRM VC4 V3D driver
reboot='false'
if grep -q '^dtoverlay=vc4-kms-v3d' /boot/config.txt; then
	echo 'Disabling DRM VC4 V3D driver...'
	backupFile /boot/config.txt
	sed 's|^\(dtoverlay=vc4-kms-v3d\)$|#\1|' /boot/config.txt
	reboot='true'
fi

if [ ! -e /etc/systemd/system/rpi_no_hdmi.service ] || ! diff -q etc/systemd/system/rpi_no_hdmi.service /etc/systemd/system/rpi_no_hdmi.service > /dev/null; then
	cp etc/systemd/system/rpi_no_hdmi.service /etc/systemd/system/rpi_no_hdmi.service
fi

systemctl enable rpi_no_hdmi

if $reboot; then
	echo
	echo 'After restarting your device HDMI will be disabled.'
	echo
	read -p 'Press Ctrl-C to quit or any other key to reboot your device.' -n 1
	echo

	reboot & exit
else
	systemctl start rpi_no_hdmi

	echo
	echo 'HDMI has been disabled.'
	echo 'You can enable HDMI by executing:'
	echo '  /usr/bin/tvservice -p'
fi
