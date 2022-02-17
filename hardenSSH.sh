#!/bin/bash

# Check if we are root
if [ "$(id -u)" -ne 0 ]; then
	echo 'You should run this configuration script as root!'
	exit 1
fi

TIMESTAMP=`date '+%Y%m%d%H%M%S'`
backupFile() {
	[ -f "$1" ] && [ ! -f "$1".old$TIMESTAMP ] && cp -p "$1" "$1".old$TIMESTAMP
}

[ -z "$SUDO_USER" ] && SUDO_USER=pi
[ -z "$SUDO_UID" ] && SUDO_UID=1000
[ -z "$SUDO_GID" ] && SUDO_GID=1000

SUDO_USER_HOME=`eval echo ~$SUDO_USER`

if [ ! -s $SUDO_USER_HOME/.ssh/authorized_keys ]; then
	# Ask for SSH public key
	echo 'It is recommended to use key based authentication for SSH'
	echo 'Your SSH public key, leave empty to keep using a password instead'
	read 'SSHPUBLICKEY'

	#ToDo Validate SSH public key

	if [ -n "$SSHPUBLICKEY" ]; then
		echo
		mkdir -p $SUDO_USER_HOME/.ssh
		echo "$SSHPUBLICKEY" >> $SUDO_USER_HOME/.ssh/authorized_keys
		chown -R $SUDO_UID:$SUDO_GID $SUDO_USER_HOME/.ssh
		// Disable password of sudo user
		usermod -p "*" $SUDO_USER
	elif [ -e /run/sshwarn ]; then
		# Change user password
		echo
		echo "You need to change the default password for user $SUDO_USER"
		passwd $SUDO_USER
	fi
fi

# Disable password authentication in SSH daemon if authorized_keys are configured
if [ -s $SUDO_USER_HOME/.ssh/authorized_keys ]; then
	echo
	echo 'You are using key based authentication for SSH, disabling password based authentication'
	backupFile /etc/ssh/sshd_config
	sed 's|^#\?ChallengeResponseAuthentication .*$|ChallengeResponseAuthentication no|' -i /etc/ssh/sshd_config
	sed 's|^#\?PasswordAuthentication .*$|PasswordAuthentication no|' -i /etc/ssh/sshd_config
	sed 's|^#\?UsePAM .*$|UsePAM no|' -i /etc/ssh/sshd_config
fi
