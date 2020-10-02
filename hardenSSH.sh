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

if [ ! -s ~pi/.ssh/authorized_keys ]; then
	# Ask for SSH public key
	echo 'It is recommended to use key based authentication for SSH'
	echo 'Your SSH public key, leave empty to keep using a password instead'
	read 'SSHPUBLICKEY'

	#ToDo Validate SSH public key

	if [ -n "$SSHPUBLICKEY" ]; then
		echo
		mkdir -p ~pi/.ssh
		echo "$SSHPUBLICKEY" >> ~pi/.ssh/authorized_keys
		chown -R pi:pi ~pi/.ssh
	elif [ -e /run/sshwarn ]; then
		# Change user pi password
		echo
		echo 'You need to change the default password for user pi'
		passwd pi
	fi
fi

# Disable password authentication in SSH daemon if authorized_keys are configured
if [ -s ~pi/.ssh/authorized_keys ]; then
	echo
	echo 'You are using key based authentication for SSH, disabling password based authentication'
	backupFile /etc/ssh/sshd_config
	sed 's|^#\?ChallengeResponseAuthentication .*$|ChallengeResponseAuthentication no|' -i /etc/ssh/sshd_config
	sed 's|^#\?PasswordAuthentication .*$|PasswordAuthentication no|' -i /etc/ssh/sshd_config
	sed 's|^#\?UsePAM .*$|UsePAM no|' -i /etc/ssh/sshd_config
fi
