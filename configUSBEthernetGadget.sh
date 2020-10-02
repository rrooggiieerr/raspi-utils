#!/bin/bash

# Check if we are root
if [ "$(id -u)" -ne 0 ]; then
	echo 'You should run this installation script as root!'
	exit 1
fi

#ToDo Edit /boot/config.txt
# [pi0w]
# # Enable USB Gadget driver
# dtoverlay=dwc2

cp etc/init.d/usbethernetgadget /etc/init.d/

update-rc.d usbethernetgadget defaults
update-rc.d usbethernetgadget enable

# Install dnsmasq
if [ ! -e /usr/sbin/dnsmasq ]; then
        apt-get install -y dnsmasq
fi

# Disable DHCP client
if ! grep -q "^interface usb0" /etc/dhcpcd.conf; then
	cat << EOF >> /etc/dhcpcd.conf

interface usb0
static ip_address=192.168.151.1/30
EOF
fi

# Configure DHCP server
if ! grep -q "^interface=usb0" /etc/dnsmasq.conf; then
	cat << EOF >> /etc/dnsmasq.conf

interface=usb0
  dhcp-range=192.168.151.2,192.168.151.2,255.255.255.252,1m
EOF
fi
