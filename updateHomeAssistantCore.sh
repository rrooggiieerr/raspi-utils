#!/bin/bash

# Check if we are root
if [ "$(id -u)" -ne 0 ]; then
	echo 'You should run this update script as root!'
	exit 1
fi

systemctl stop home-assistant@homeassistant
sudo -u homeassistant -H -s /usr/bin/bash -c "(cd /srv/homeassistant && python3.9 -m venv . && source /srv/homeassistant/bin/activate && pip3 install --upgrade homeassistant)"
systemctl start home-assistant@homeassistant
