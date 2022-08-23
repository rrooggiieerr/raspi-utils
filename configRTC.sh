#!/bin/bash
#
# Real Time Clock
#

echo 'Description goed here.
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

if [ ! -e /usr/sbin/i2cdetect ]; then
	echo 'Installing I2C packages...'
	apt-get install -y i2c-tools
fi

if [ ! -e /dev/i2c-1 ]; then
	echo 'Configuring I2C subsystem...'

	if ! grep -q '^i2c-dev' /etc/modules; then
		backupFile /etc/modules
		echo 'i2c-dev' >> /etc/modules
	fi

	# Enable i2c in boot config
	if grep -q '#\?dtparam=i2c_arm=' /boot/config.txt; then
		backupFile /boot/config.txt
		sed 's|^#\?dtparam=i2c_arm=.*$|dtparam=i2c_arm=on|' -i /boot/config.txt
	fi

	echo ''
	echo 'The I2C subsystem is now configured. You need to restart your device and
continue the installation by executing the installation script again.
'
	read -p 'Press Ctrl-C to quit or any other key to reboot your device' -n 1
	echo

	reboot & exit
fi

I2CDETECT_RESPONSE=`/usr/sbin/i2cdetect -y 1 0x32 0x68`
if grep -q ' 32 ' <<< "$I2CDETECT_RESPONSE"; then
	# RTC as used by PiSugar2
	if grep -vq "dtoverlay=i2c-rtc," /boot/config.txt; then
		echo 'Configurinh Real Time Clock driver...'

		echo 'dtoverlay=i2c-rtc,sd3078' >> /boot/config.txt

		echo ''
		echo 'The Real Time Clock driver is now configured. You need to restart and continue the
installation by executing the installation script again.
'
		read -p 'Press Ctrl-C to quit or any other key to reboot your device' -n 1
		echo

		reboot & exit
	fi
elif grep -q ' 68 ' <<< "$I2CDETECT_RESPONSE"; then
	if grep -vq "dtoverlay=i2c-rtc," /boot/config.txt; then
		echo 'Configurinh Real Time Clock driver...'

		#ToDo How to detect which device is used?
		#echo 'dtoverlay=i2c-rtc,ds1307' >> /boot/config.txt
		#echo 'dtoverlay=i2c-rtc,pcf8523' >> /boot/config.txt
		echo 'dtoverlay=i2c-rtc,ds3231' >> /boot/config.txt

		echo ''
		echo 'The Real Time Clock driver is now configured. You need to restart and continue the
installation by executing the installation script again.
'
		read -p 'Press Ctrl-C to quit or any other key to reboot your device' -n 1
		echo

		reboot & exit
	fi
elif grep -q ' UU ' <<< "$I2CDETECT_RESPONSE"; then
	#ToDo Check if we have a network connection and if the current time is set using NTP
	hwclock -w

	# Disable the fake hardware clock script and enable the RTC script
	update-rc.d -f fake-hwclock disable
	#update-rc.d -f hwclock.sh enable

	# Incase we want to remove the fake hardware clock all together
	#apt-get -y remove fake-hwclock
	#update-rc.d -f fake-hwclock remove
fi
