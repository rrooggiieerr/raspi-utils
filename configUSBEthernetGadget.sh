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

#ToDo Edit /boot/config.txt
# [pi0w]
# # Enable USB Gadget driver
# dtoverlay=dwc2

cp etc/init.d/usbethernetgadget /etc/init.d/

update-rc.d usbethernetgadget defaults
update-rc.d usbethernetgadget enable

# Install dnsmasq
if [ ! -e /usr/sbin/dnsmasq ]; then
	apt -y update
	apt -y upgrade
	
	echo 'Installing dnsmasq package'
	apt -y install dnsmasq
fi

# Configure fixed IP address
#if ! grep -q '^interface usb0' /etc/dhcpcd.conf; then
#	backupFile /etc/dhcpcd.conf
#	cat << EOF >> /etc/dhcpcd.conf
#
#interface usb0
#static ip_address=192.168.151.1/30
#EOF
#fi

# Configure fixed IP address
if [ ! -e /etc/network/interfaces.d/usb0 ]; then
	cat << EOF > /etc/network/interfaces.d/usb0
auto usb0
allow-hotplug usb0 
iface usb0 inet static
	address 192.168.151.1
	netmask 255.255.255.252
EOF
fi

# Configure DHCP server
if ! grep -q '^interface=usb0' /etc/dnsmasq.conf; then
	backupFile /etc/dnsmasq.conf
	cat << EOF >> /etc/dnsmasq.conf

interface=usb0
  dhcp-range=192.168.151.2,192.168.151.2,255.255.255.252,1m
EOF
fi
