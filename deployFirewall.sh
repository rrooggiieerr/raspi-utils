#!/bin/bash
#

# Check if we are root
if [ "$(id -u)" -ne 0 ]; then
	echo 'You should run this installation script as root!'
	exit 1
fi

TIMESTAMP=`date '+%Y%m%d%H%M%S'`
backupFile() {
	[ -f "$1" ] && [ ! -f "$1".old$TIMESTAMP ] && cp -p "$1" "$1".old$TIMESTAMP
}

# Setup Uncomplicated Firewall
if ! which ufw > /dev/null; then
	apt-get install -y ufw
fi

ufw default deny incoming
ufw allow ssh

# Disable logging 
ufw logging off

ufw enable

# Setup Fail2Ban
if ! which fail2ban-client > /dev/null; then
	apt-get install -y fail2ban
fi

[ ! -e /etc/fail2ban/jail.local ] && cp -p /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

if ! grep -q ufw /etc/fail2ban/jail.local; then
	backupFile /etc/fail2ban/jail.local

	# Set default banaction to ufw
	sed 's|^\(banaction = \)[^%].*$|\1ufw|' -i /etc/fail2ban/jail.local
	sed 's|^\(banaction_allports = \)[^%].*$|\1ufw|' -i /etc/fail2ban/jail.local
fi
