#!/bin/sh
ROOT_PWHASH=$(awk -F: '/^root:/ {print $2}' /etc/shadow)
if [ -z "$ROOT_PWHASH" ]; then
	echo "Error getting current root password" >&2
	exit 1
fi

echo "Setting fwenv 8311_root_pwhash to '$ROOT_PWHASH'"
fw_setenv 8311_root_pwhash "$ROOT_PWHASH"
fw_setenv 8311_root_pwhash "$ROOT_PWHASH"
