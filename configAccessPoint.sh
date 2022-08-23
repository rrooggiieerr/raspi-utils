#!/bin/bash
#
# Configures a wireless interface to be an Access Point
#
# By Rogier van Staveren
# https://github.com/rrooggiieerr/raspi-utils/
#

METHOD='hostapd'
#METHOD='wpa_supplicant'

echo 'This script will configure a wireless interface to be an Access Point.
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

# Check if the installation is run from a remote SSH connection
ISREMOTELOGIN=`pstree -ps $$ | grep -q ssh && echo true || echo false`

if [ -s /etc/hostapd/hostapd.conf ]; then
	# Read the current Access Point configuration
	HOSTAPDCONF=`cat /etc/hostapd/hostapd.conf`
	INTERFACE=`sed -n 's|^interface=\(.*\)$|\1|p' <<< "$HOSTAPDCONF"`
	SSID=`sed -n 's|^ssid=\(.*\)$|\1|p' <<< "$HOSTAPDCONF"`
	PASSPHRASE=`sed -n 's|^wpa_passphrase=\(.*\)$|\1|p' <<< "$HOSTAPDCONF"`
	METHOD='hostapd'
else
	# Generate a somewhat unique name for the Host AP
	SSID='ap'`shuf -i 1000-9999 -n 1`
fi

mapfile -t INTERFACES < <(/usr/sbin/iw dev | sed -n 's|^\W*Interface \(.*\)$|\1|p')
CHOICE=''
for I in ${!INTERFACES[@]}; do
	_INTERFACE="${INTERFACES[$I]}"
	printf '%2d %s\n' "$I" "$_INTERFACE"
	if [ "$INTERFACE" == "$_INTERFACE" ]; then
		CHOICE="$I"
	fi
done
while true; do
	read -p 'Select the interface you would like to use: ' -e -i "$CHOICE" 'CHOICE'
	echo -n "$CHOICE" | egrep -q "^[0-9]+$" && [ -n "${INTERFACES[$CHOICE]}" ] && break
done
INTERFACE="${INTERFACES[$CHOICE]}"

if [ -f "/etc/network/interfaces.d/$INTERFACE" ]; then
	IPADDRESS=`sed -n 's|^\s*address\s*\(\S*\).*$|\1|p' "/etc/network/interfaces.d/$INTERFACE"`
	NETMASK=`sed -n 's|^\s*netmask\s*\(\S*\).*$|\1|p' "/etc/network/interfaces.d/$INTERFACE"`
	NETWORK=`sed -n 's|^\s*network\s*\(\S*\).*$|\1|p' "/etc/network/interfaces.d/$INTERFACE"`
	BROADCAST=`sed -n 's|^\s*broadcast\s*\(\S*\).*$|\1|p' "/etc/network/interfaces.d/$INTERFACE"`
	OCTET=`sed -n 's|^[0-9]*\.[0-9]*\.\([0-9]*\)\.[0-9]*$|\1|p' <<< "$IPADDRESS"`
	WPACONF=`sed -n 's|^\s*wpa-conf\s*\(\S*\).*$|\1|p' "/etc/network/interfaces.d/$INTERFACE"`
else
	# We take a number between 128 and 254 to create an IP range for the Access Point
	OCTET=`shuf -i 128-254 -n 1`
	NETWORK="192.168.$OCTET.0"
	#TODO Check if network is already used
	IPADDRESS="192.168.$OCTET.1"
	NETMASK='255.255.255.0'
	BROADCAST="192.168.$OCTET.255"
	WPACONF="/etc/wpa_supplicant/wpa_supplicant-$INTERFACE.conf"
fi

while true; do
	read -e -p 'Network name: ' -e -i "$SSID" 'SSID'
	# Check SSID length, max 32 characters
	((`echo -n "$SSID" | wc -c` <= 32)) && break
done

while true; do
	read -p "Passphrase: " -e -i "$PASSPHRASE" 'PASSPHRASE'
	# Check passphrase length, 8 to 63 charactrs
	echo -n "$PASSPHRASE" | egrep -q "^.{8,}$" && break
done

echo -n -e "
Host Access Point configuration summary
Interface: $INTERFACE
SSID: $SSID
Passphrase: $PASSPHRASE
IP Address: $IPADDRESS
Netmask: $NETMASK
Broadcast: $BROADCAST
Press Ctrl-C to stop or any other key to continue"
read -n 1
echo

INSTALLPKG=''
if [ ! -e /usr/sbin/dnsmasq ]; then
	INSTALLPKG="$INSTALLPKG dnsmasq"
fi

if [ "$METHOD" == 'hostapd' ] && [ ! -f /usr/sbin/hostapd ]; then
	INSTALLPKG="$INSTALLPKG hostapd"
fi

if [ -n "$INSTALLPKG" ]; then
	echo
	echo 'Installing required packages for your Access Point'
	apt install -y $INSTALLPKG || exit 1
	[ "$METHOD" == 'hostapd' ] && systemctl stop hostapd
fi

echo
echo 'Configuring Access Point...'
# Configure network interface
if [ ! -f "/etc/network/interfaces.d/$INTERFACE" ]; then
	echo 'Configuring network interface'
	cat << EOF > "/etc/network/interfaces.d/$INTERFACE"
auto $INTERFACE
allow-hotplug $INTERFACE
iface $INTERFACE inet static
	address $IPADDRESS
	netmask $NETMASK
	network $NETWORK
	broadcast $BROADCAST
EOF
	if [ "$METHOD" == 'wpa_supplicant' ]; then
		echo -e "\twpa-conf $WPACONF" >> "/etc/network/interfaces.d/$INTERFACE"
	fi
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
	echo -e "\ndenyinterfaces $INTERFACE" >> /etc/dhcpcd.conf
	systemctl restart dhcpcd
elif ! grep -q "^denyinterfaces\b.*\b$INTERFACE\b.*" /etc/dhcpcd.conf; then
	echo "Disabling DHCP client for interface $INTERFACE..."
	backupFile /etc/dhcpcd.conf
	sed "s|^denyinterfaces\b.*$|\0 $INTERFACE|" -i /etc/dhcpcd.conf
	systemctl restart dhcpcd
fi

# Configure DHCP server
if [ ! -e "/etc/dnsmasq.d/$INTERFACE" ]; then
	echo 'Configuring DHCP server...'
	cat << EOF > "/etc/dnsmasq.d/$INTERFACE"
interface=$INTERFACE
  dhcp-option=3
  dhcp-range=192.168.$OCTET.20,192.168.$OCTET.254,$NETMASK,24h
EOF
	systemctl restart dnsmasq
fi

# Configure Zeroconf
if grep -q "^#allow-interfaces=" /etc/avahi/avahi-daemon.conf; then
	echo 'Configuring Zeroconf...'
	backupFile /etc/avahi/avahi-daemon.conf
	sed "s|^#\?allow-interfaces=.*$|allow-interfaces=$INTERFACE|g" -i /etc/avahi/avahi-daemon.conf
	systemctl restart avahi-daemon
elif ! grep -q "^allow-interfaces=.*\b$INTERFACE\b.*" /etc/avahi/avahi-daemon.conf; then
	echo 'Configuring Zeroconf'
	backupFile /etc/avahi/avahi-daemon.conf
	sed "s|^allow-interfaces=.*$|\0,$INTERFACE|g" -i /etc/avahi/avahi-daemon.conf
	systemctl restart avahi-daemon
fi

if [ "$METHOD" == 'hostapd' ]; then
	if [ -s /etc/hostapd/hostapd.conf ]; then
		HOSTAPDCONF=`sed "s|^interface=.*$|interface=$INTERFACE|;s|^ssid=.*$|ssid=$SSID|;s|^wpa_passphrase=.*$|wpa_passphrase=$PASSPHRASE|" /etc/hostapd/hostapd.conf`
	else
		HOSTAPDCONF="interface=$INTERFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASSPHRASE
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0"
	fi

	# Check if HOSTAPDCONF and /etc/hostapd/hostapd.conf differ
	HOSTAPHASCHANGED='false'
	if [ ! -e /etc/hostapd/hostapd.conf ] || ! ( echo "$HOSTAPDCONF" | diff -q /etc/hostapd/hostapd.conf - > /dev/null ); then
		backupFile /etc/hostapd/hostapd.conf
		echo "$HOSTAPDCONF" > /etc/hostapd/hostapd.conf
		chmod 600 /etc/hostapd/hostapd.conf
		HOSTAPHASCHANGED='true'
	fi

	systemctl unmask hostapd	
	systemctl enable hostapd

	if $HOSTAPHASCHANGED && $ISREMOTELOGIN; then
		echo
		echo 'Your Access Point is now configured. You need to restart your device.'

		read -p 'Press Ctrl-C to quit or any other key to reboot your device' -n 1
		echo

		reboot & exit
	elif $HOSTAPHASCHANGED; then
		# Restart Host AP interface
		#RS I have not tested this as I always connect remotely
		ifdown "$INTERFACE"
		ifup "$INTERFACE"

		systemctl restart hostapd
	fi
fi
