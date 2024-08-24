#!/bin/sh /etc/rc.common

_lib_8311 2>/dev/null || . /lib/8311.sh

START=17

boot() {
	FWENV_BACK="/ptconf/8311/fwenvs_backup.env"
	if [ ! -f "$FWENV_BACK" ]; then
		mkdir -p /ptconf/8311
		echo "Backing up existing 8311 fwenvs before resetting them..." | to_console
		fw_printenv | pcre2grep '^(8311_[^=]+)=' > "$FWENV_BACK"

		FWENVS=$(cat "$FWENV_BACK" | pcre2grep -o1 '^([^=]+)=')
		for FWENV in $FWENVS; do
			echo "Clearing fwenv '$FWENV'..." | to_console
			fwenv_set "$FWENV"
		done

		echo "Rebooting" | to_console
		reboot
		return 1
	fi
}
