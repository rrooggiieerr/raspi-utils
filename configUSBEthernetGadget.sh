#!/bin/bash
#
# Configures a Raspbery Pi Zero or 4 USB port to be an USB Ethernet Gadget
#
# By Rogier van Staveren
# https://github.com/rrooggiieerr/raspi-utils/
#

INTERFACE="usb0"

echo 'This script will configure a Raspbery Pi Zero or 4 USB port to be an USB Ethernet Gadget.
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

#ToDo Edit /boot/config.txt
# [pi0]
# # Enable USB Gadget driver
# dtoverlay=dwc2
# 
# [pi4]
# # Enable USB Gadget driver
# dtoverlay=dwc2

if [ -f "/etc/network/interfaces.d/$INTERFACE" ]; then
	IPADDRESS=`sed -n 's|^\s*address\s*\(\S*\).*$|\1|p' "/etc/network/interfaces.d/$INTERFACE"`
	NETMASK=`sed -n 's|^\s*netmask\s*\(\S*\).*$|\1|p' "/etc/network/interfaces.d/$INTERFACE"`
	NETWORK=`sed -n 's|^\s*network\s*\(\S*\).*$|\1|p' "/etc/network/interfaces.d/$INTERFACE"`
	BROADCAST=`sed -n 's|^\s*broadcast\s*\(\S*\).*$|\1|p' "/etc/network/interfaces.d/$INTERFACE"`
	OCTET=`sed -n 's|^[0-9]*\.[0-9]*\.\([0-9]*\)\.[0-9]*$|\1|p' <<< "$IPADDRESS"`
else
	# We take a number between 128 and 254 to create an IP range for the USB Ethernet Gadget
	OCTET=`shuf -i 128-254 -n 1`
	NETWORK="192.168.$OCTET.0"
	#TODO Check if network is already used
	IPADDRESS="192.168.$OCTET.1"
	NETMASK='255.255.255.252'
	BROADCAST="192.168.$OCTET.3"
fi

cp etc/init.d/usbethernetgadget /etc/init.d/

update-rc.d usbethernetgadget defaults
update-rc.d usbethernetgadget enable

# Install dnsmasq
if [ ! -e /usr/sbin/dnsmasq ]; then
	apt update -y || exit 1
	apt upgrade -y || exit 1

	echo 'Installing dnsmasq package'
	apt install dnsmasq -y || exit 1
fi

# Configure network interface
if [ ! -e "/etc/network/interfaces.d/$INTERFACE" ]; then
	echo 'Configuring network interface...'
	cat << EOF > "/etc/network/interfaces.d/$INTERFACE"
auto $INTERFACE
allow-hotplug $INTERFACE
iface $INTERFACE inet static
	address $IPADDRESS
	netmask $NETMASK
	network $NETWORK
	broadcast $BROADCAST
EOF
fi

# Configure hosts file
if ! grep -q "^$IPADDRESS\s" /etc/hosts; then
	echo 'Configuring hosts file...'
	backupFile /etc/hosts
	echo "$IPADDRESS	$HOSTNAME" >> /etc/hosts
fi

# Disable DHCP client
if ! grep -q "^denyinterfaces\b" /etc/dhcpcd.conf; then
	echo "Disabling DHCP client for interface $INTERFACE..."
	backupFile /etc/dhcpcd.conf
	echo -e "\ndenyinterfaces\b.*\b$INTERFACE\b.*" >> /etc/dhcpcd.conf
	systemctl restart dhcpcd
elif ! grep -q "^denyinterfaces\b.*\b$INTERFACE\b.*" /etc/dhcpcd.conf; then
	echo "Disabling DHCP client for interface $INTERFACE..."
	backupFile /etc/dhcpcd.conf
	sed "s|^denyinterfaces .*$|\0 $INTERFACE|" -i /etc/dhcpcd.conf
	systemctl restart dhcpcd
fi

# Configure DHCP server
if [ ! -e "/etc/dnsmasq.d/$INTERFACE" ]; then
	echo 'Configuring DHCP server...'
	cat << EOF > "/etc/dnsmasq.d/$INTERFACE"
interface=$INTERFACE
  dhcp-option=$INTERFACE,3
  dhcp-range=192.168.$OCTET.2,192.168.$OCTET.2,$NETMASK,1m
EOF
fi

# Configure Zeroconf
if grep -q "^#allow-interfaces=" /etc/avahi/avahi-daemon.conf; then
	echo 'Configuring Zeroconf...'
        backupFile /etc/avahi/avahi-daemon.conf
        sed "s|^#\?allow-interfaces=.*$|allow-interfaces=$INTERFACE|g" -i /etc/avahi/avahi-daemon.conf
	systemctl restart avahi-daemon
elif ! grep -q "^allow-interfaces=.*\b$INTERFACE\b.*" /etc/avahi/avahi-daemon.conf; then
	echo 'Configuring Zeroconf...'
        backupFile /etc/avahi/avahi-daemon.conf
        sed "s|^allow-interfaces=.*$|\0,$INTERFACE|g" -i /etc/avahi/avahi-daemon.conf
	systemctl restart avahi-daemon
fi
