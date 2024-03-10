#!/bin/sh /etc/rc.common

_lib_8311 2>/dev/null || . /lib/8311.sh

START=79

start() {
	# 8311 MOD: fwenv to set Logical ONU ID
	LOID=$(get_8311_loid)
	[ -n "$LOID" ] && set_8311_loid "$LOID"

	# 8311 MOD: fwenv to set Logical Password
	LPWD=$(get_8311_lpwd)
	[ -n "$LPWD" ] && set_8311_lpwd "$LPWD"

	# set mib file from mib_file fwenv
	MIB_FILE=$(get_8311_mib_file)
	[ -n "$MIB_FILE" ] && set_8311_mib_file "$MIB_FILE"

	# fwenv for setting eth0_0 speed settings with ethtool
	ETH_SPEED=$(get_8311_ethtool)
	[ -n "$ETH_SPEED" ] && set_8311_ethtool "$ETH_SPEED"

	# fwenv for setting the root account password hash
	ROOT_PWHASH=$(get_8311_root_pwhash)
	[ -n "$ROOT_PWHASH" ] && set_8311_root_pwhash "$ROOT_PWHASH"

	# fwenv to change the slot presented to the OLT
	PON_SLOT=$(get_8311_pon_slot)
	[ -n "$PON_SLOT" ] && set_8311_pon_slot "$PON_SLOT"

	# 8311 MOD: Set GPON Serial Number and Vendor ID
	GPON_SN=$(get_8311_gpon_sn)
	VENDOR_ID=$(get_8311_vendor_id)
	if [ -n "$GPON_SN" ]; then
		VENDOR_ID="${VENDOR_ID:-$(echo "$GPON_SN" | head -c 4)}"
		set_8311_gpon_sn "$GPON_SN"
	fi

	[ -n "$VENDOR_ID" ] && set_8311_vendor_id "$VENDOR_ID"

	# 8311 MOD: fwenv to set Device SN
	DEVICE_SN=$(get_8311_device_sn)
	[ -n "$DEVICE_SN" ] && set_8311_device_sn "$DEVICE_SN"

	# 8311 MOD: Set Registration ID
	REG_ID_HEX=$(get_8311_reg_id_hex)
	[ -n "$REG_ID_HEX" ] && set_8311_reg_id_hex "$REG_ID_HEX"

	# 8311 MOD: fwenvs to set IP Host Host Name and Domain Name
	IPHOST_HOSTNAME=$(get_8311_iphost_hostname)
	set_8311_iphost_hostname "$IPHOST_HOSTNAME"

	IPHOST_DOMAIN=$(get_8311_iphost_domain)
	set_8311_iphost_domain "$IPHOST_DOMAIN"

	# 8311 MOD: Set software versions (omci_pipe.sh meg 7 0/1)
	SW_VERSION_A=$(get_8311_sw_ver A)
	[ -n "$SW_VERSION_A" ] && set_8311_sw_ver "A" "$SW_VERSION_A"

	SW_VERSION_B=$(get_8311_sw_ver B)
	[ -n "$SW_VERSION_B" ] && set_8311_sw_ver "B" "$SW_VERSION_B"

	# 8311 MOD: Set hardware version (omci_pipe.sh meg 256 0)
	HW_VERSION=$(get_8311_hw_ver)
	[ -n "$HW_VERSION" ] && set_8311_hw_ver "$HW_VERSION"

	# 8311 MOD: Set equipment id (omci_pipe.sh meg 257 0)
	EQUIPMENT_ID=$(get_8311_equipment_id)
	[ -n "$EQUIPMENT_ID" ] && set_8311_equipment_id "$EQUIPMENT_ID"
}

boot() {
	if [ "$(get_8311_module_type)" = "potron" ]; then
		echo "Potrontec module detected, setting optic.common.tx_en_mode to 3" | to_console
		uci set "optic.common.tx_en_mode"="3"
	else
		uci set "optic.common.tx_en_mode"="0"
	fi
	uci commit "optic"

	start "$@"

	# 8311 MOD: start vlansd script
	/usr/sbin/8311-vlansd.sh &
}
