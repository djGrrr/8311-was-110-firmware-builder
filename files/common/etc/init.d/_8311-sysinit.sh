#!/bin/sh /etc/rc.common

_lib_8311 2>/dev/null || . /lib/8311.sh

START=18

start() {
	# 8311 MOD: set LCT MAC
	LCT_MAC=$(get_8311_lct_mac)
	set_8311_lct_mac "$LCT_MAC"

	# 8311 MOD: set IP Host MAC
	IPHOST_MAC=$(get_8311_iphost_mac)
	set_8311_iphost_mac "$IPHOST_MAC"
}

boot() {
	# 8311 MOD: Remove persistent root
	_8311_check_persistent_root

	# 8311 MOD: persistent server and client key
	DROPBEAR_RSA_KEY=$(uci -qc /ptconf/8311 get dropbear.rsa_key.value)
	DROPBEAR_PUBKEY=$(uci -qc /ptconf/8311 get dropbear.public_key.value)
	DROPBEAR_PUBKEY_BASE64=$(uci -qc /ptconf/8311 get dropbear.public_key.encryflag)

	[ -f "/ptconf/8311/dropbear" ] && rm -fv "/ptconf/8311/dropbear"
	mkdir -p /ptconf/8311 /ptconf/8311/dropbear /ptconf/8311/.ssh
	chmod 700 /ptconf/8311/dropbear /ptconf/8311/.ssh
	ln -fsv /ptconf/8311/.ssh/authorized_keys /ptconf/8311/dropbear/authorized_keys

	if [ -n "$DROPBEAR_RSA_KEY" ]; then
		echo "Migrating dropbear.rsa_key to /ptconf/8311/dropbear/dropbear_rsa_host_key" | tee -a /dev/console

		echo "$DROPBEAR_RSA_KEY" | base64 -d > /ptconf/8311/dropbear/dropbear_rsa_host_key
		chmod 600 /ptconf/8311/dropbear/dropbear_rsa_host_key
	fi

	if [ -n "$DROPBEAR_PUBKEY" ]; then
		echo "Migrating dropbear.public_key to /ptconf/8311/.ssh/authorized_keys" | tee -a /dev/console

		if [ "$DROPBEAR_PUBKEY_BASE64" = "1" ]; then
			echo "$DROPBEAR_PUBKEY" | base64 -d > /ptconf/8311/.ssh/authorized_keys
		else
			echo "$DROPBEAR_PUBKEY" > /ptconf/8311/.ssh/authorized_keys
		fi

		chmod 600 /ptconf/8311/.ssh/authorized_keys
	fi

	start "$@"

	# 8311 MOD: start rx_los script
	/usr/sbin/8311-rx_los.sh &
}
