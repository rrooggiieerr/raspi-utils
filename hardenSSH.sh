#!/bin/bash
#
# Increase the security of the SSH server and client
#
# By Rogier van Staveren
# https://github.com/rrooggiieerr/raspi-utils/
#

echo 'This script will harden your SSH server by configuring key based authentication,
disabling password authentication and host key verification.
'

# Check if we are root
if [ "$(id -u)" -ne 0 ]; then
	echo 'You should run this configuration script as root!'
	exit 1
else
	read -p 'Press Ctrl-C to quit or any other key to continue.' -n 1
	echo
fi

TIMESTAMP=`date '+%Y%m%d%H%M%S'`
backupFile() {
	[ -f "$1" ] && [ ! -f "$1.old$TIMESTAMP" ] && cp -p "$1" "$1.old$TIMESTAMP"
}

[ -z "$SUDO_USER" ] && SUDO_USER=pi
[ -z "$SUDO_UID" ] && SUDO_UID=1000
[ -z "$SUDO_GID" ] && SUDO_GID=1000

SUDO_USER_HOME=`eval echo ~$SUDO_USER`

if [ ! -s "$SUDO_USER_HOME/.ssh/authorized_keys" ]; then
	# Ask for SSH public key
	echo 'It is recommended to use key based authentication for SSH.'
	echo
	read -p 'Your SSH public key, leave empty to keep using a password instead: ' SSHPUBLICKEY

	#ToDo Validate SSH public key

	if [ -n "$SSHPUBLICKEY" ]; then
		echo
		mkdir -p "$SUDO_USER_HOME/.ssh"
		echo "$SSHPUBLICKEY" >> "$SUDO_USER_HOME/.ssh/authorized_keys"
		chown -R "$SUDO_UID:$SUDO_GID" "$SUDO_USER_HOME/.ssh"
	elif [ -e /run/sshwarn ]; then
		# Change user password
		echo
		echo "You need to change the default password for user $SUDO_USER"
		passwd "$SUDO_USER"
	fi
fi

# Disable password authentication in SSH daemon if authorized_keys are configured
if [ -s "$SUDO_USER_HOME/.ssh/authorized_keys" ]; then
	echo
	echo 'You are using key based authentication for SSH.'

	if [ ! -e /etc/ssh/sshd_config.d/disablePasswordAuthentication ]; then
		echo 'Disabling password based authentication...'
		echo 'PasswordAuthentication no
ChallengeResponseAuthentication no' > /etc/ssh/sshd_config.d/disablePasswordAuthentication
	fi

	# Disable password of sudo user
	echo "Disabling password for user $SUDO_USER..."
	usermod -p '*' "$SUDO_USER"
fi

if [ ! -e /etc/ssh/ssh_config.d/VerifyHostKeyDNS ]; then
	echo 'Enabling host key verification...'
	echo 'Host *
	VerifyHostKeyDNS yes' > /etc/ssh/ssh_config.d/VerifyHostKeyDNS
fi

systemctl reload sshd

echo '
SSH has been hardened.'
