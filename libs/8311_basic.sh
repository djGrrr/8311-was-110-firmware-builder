#!/bin/sh

_lib_8311 2>/dev/null || . /lib/8311.sh
_lib_hexbin 2>/dev/null || . /lib/functions/hexbin.sh

_set_8311_gpon_sn() {
	uci set gpon.ploam.nSerial="$1"
	uci commit gpon
}

_set_8311_device_sn() {
	# not implemented
	return 0
}

_set_8311_vendor_id() {
	# handled in base function
	return 0
}

_set_8311_reg_id_hex() {
	local hex=$({ echo "$1" | hex2str; cat /dev/zero 2>/dev/null; } | head -c 36 | str2hex | sed -r 's#([0-9A-F]{2})# 0x\1#gI')
	uci set gpon.ploam.regID="$hex"
	uci commit gpon
}

_set_8311_sw_ver() {
	# handled in uboot_img_vars.sh
	return 0
}

_set_8311_override_active() {
	# handled in uboot_img_vars.sh
	return 0
}

_set_8311_hw_ver() {
	# handled in base function
	return 0
}

_set_8311_equipment_id() {
	# handled in base function
	return 0
}

_set_8311_ipaddr() {
	# handled by uci-defaults
	return 0
}

_set_8311_netmask() {
	# handled by uci-defaults
	return 0
}

_set_8311_gateway() {
	# handled by uci-defaults
	return 0
}

_set_8311_lct_mac() {
	# handled by uci-defaults
	return 0
}

_set_8311_iphost_mac() {
	# handled by uci-defaults
	return 0
}
