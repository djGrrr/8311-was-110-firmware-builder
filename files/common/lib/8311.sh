#!/bin/sh

_lib_8311() {
	return 0
}

. "/lib/pon.sh"
. "/lib/8311_backend.sh"

lib_hexbin 2>/dev/null || . /lib/functions/hexbin.sh

to_console() {
	awk '{print "[8311] " $0}' >&1 | tee -a /dev/console  | logger -t "8311" -p daemon.info
}

strtoupper() {
	tr '[a-z]' '[A-Z]'
}

strtolower() {
	tr '[A-Z]' '[a-z]'
}

ipv4() {
	grep -E '^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$'
}

fwenv_get_8311() {
	fwenv_get --8311 "$@"
}

fwenv_set_8311() {
	fwenv_set --8311 "$@"
}

uci_set() {
	if [ -n "$1" ] && [ -n "$2" ]; then
		uci set "$1"="$2"
	fi
}

_8311_check_persistent_root() {
	# Remove persistent root
	PERSIST_ROOT=$(fwenv_get_8311 "persist_root")
	if ! { [ "$PERSIST_ROOT" -eq "1" ] 2>/dev/null; }; then
		echo "8311_persist_root not enabled, checking bootcmd..." | to_console
		BOOTCMD=$(fwenv_get "bootcmd")
		if ! { echo "$BOOTCMD" | grep -Eq '^\s*run\s+ubi_init\s*;\s*ubi\s+remove\s+rootfs_data\s*;\s*run\s+flash_flash\s*$'; }; then
			echo "Resetting bootcmd to default value and rebooting, set fwenv 8311_persist_root=1 to avoid this" | tee -a /dev/console

			fwenv_set bootcmd "run ubi_init; ubi remove rootfs_data; run flash_flash"

			sync
			reboot
			return 1
		fi
	fi
}

_mib_file() {
	if [ ! -f "/tmp/8311-mib-file" ]; then
		get_8311_mib_file > "/tmp/8311-mib-file"
	fi

	cat "/tmp/8311-mib-file"
}

_mib_update() {
	local ME="$1"
	local PARAM="$2"
	local VALUE="$3"
	local P='("[^"]*"|[^"]\S*)'

	sed -r "s#^(([!?]\s+)?${ME}(\s+$P){${PARAM}}\s+)($P)#\1${VALUE}#g" -i "$(_mib_file)"
}

get_8311_console_en() {
	fwenv_get_8311 "console_en"
}

get_8311_dying_gasp_en() {
	fwenv_get_8311 "dying_gasp_en"
}

get_8311_gpon_sn() {
	fwenv_get_8311 "gpon_sn" | grep -E '^[A-Za-z0-9]{4}[A-Fa-f0-9]{8}$'
}

set_8311_gpon_sn() {
	echo "Setting PON SN: $1" | to_console
	_set_8311_gpon_sn "$1"
}

get_8311_device_sn() {
	fwenv_get_8311 "device_sn"
}

set_8311_device_sn() {
#	echo "Setting device SN to: $1" | to_console
	_set_8311_device_sn "$1"
}

get_8311_vendor_id() {
	fwenv_get_8311 "vendor_id" | grep -E '^[A-Za-z0-9]{4}$'
}

set_8311_vendor_id() {
	echo "Setting PON vendor ID: $1" | to_console
	_mib_update 6 5 "\"$1\""
	_mib_update 256 1 "\"$1\""

	_set_8311_vendor_id "$1"
}

get_8311_mib_file() {
	local tmp=$(fwenv_get_8311 "mib_file")
	local mib='/etc/mibs/prx300_1U.ini'
	if [ -n "$tmp" ]; then
		if [ -f "/etc/mibs/$tmp" ]; then
			mib="/etc/mibs/$tmp"
		else
			tmp=$(readlink -f "$tmp")
			if echo "$tmp" | grep -q -E '^/etc/mibs/' && [ -f "$tmp" ]; then
				mib="$tmp"
			fi
		fi
	fi

	echo "$mib"
}

set_8311_mib_file() {
	echo "Setting OMCI MIB file: $1" | to_console
	uci -q set "omci.default.mib_file"="$1"
	uci commit omci
}

get_8311_pon_mode() {
	fwenv_get_8311 "pon_mode" "xgspon" | strtolower | sed 's/-//g' | grep -E '^xgs?pon$' || echo 'xgspon'
}

set_8311_pon_mode() {
	local display=$(echo "$1" |strtoupper | sed 's/PON/-PON/g')
	echo "Setting PON Mode to: $display" | to_console
	uci -q set "gpon.ponip.pon_mode"="$1"
	uci -q commit "gpon"
}

get_8311_omcc_version() {
	fwenv_get_8311 "omcc_version" "0xA3" | grep -E '^0x(8[2-9A-F]|[9AB][0-9A-F])$' || echo '0xA3'
}

set_8311_omcc_version() {
	echo "Setting OMCC version to: $1" | to_console
	uci -q set "omci.default.omcc_version"="$1"
    uci -q commit "omci"
}

get_8311_iop_mask() {
	# 0 - 127
	fwenv_get_8311 "iop_mask" "18" | grep -E '^(\d|[1-9]\d|1[01]\d|12[0-7])$' || echo '18'
}

set_8311_iop_mask() {
	echo "Setting OMCI Interoperability Mask to: $1" | to_console
	uci -q set "gpon.ponip.iop_mask"="$1"
	uci -q commit "gpon"
}

get_8311_reg_id_hex() {
	{ { fwenv_get_8311 "reg_id_hex" | hex2str; } || echo -n "$(fwenv_get_8311 "reg_id")"; cat /dev/zero; } 2>/dev/null | head -c 36 | str2hex | strtoupper
}


set_8311_reg_id_hex() {
	local printable=$(echo -n "$1" | hex2printable)
	echo "Setting PON registration ID to: $(echo $(echo "$1" | awk '{gsub(/.{2}/,"0x& ")}1')) ($printable)" | to_console
	_set_8311_reg_id_hex "$1"
}

get_8311_sw_ver() {
	local i1="A"
	local i2="B"
	
	{ [ "$1" = "A" ] || [ "$1" = "B" ]; } && i1="$1"
	[ "$image1" = "B" ] && i2="A"
	
	{ fwenv_get_8311 "sw_ver$i1" || fwenv_get_8311 "sw_ver" || fwenv_get_8311 "sw_ver$i2"; } | head -c 14
}

set_8311_sw_ver() {
	[ "$1" != "A" ] && [ "$1" != "B" ] && [ -z "$2" ] && return 1

	echo "Setting PON image $1 version: $2" | to_console
	_set_8311_sw_ver "$1" "$2"
}

get_8311_override_active() {
	fwenv_get_8311 override_active | grep -E '^[AB]$'
}

set_8311_override_active() {
	[ "$(active_fwbank)" = "$1" ] && return 0

	echo "Settings PON active bank to: $1" | to_console
	_set_8311_override_active "$1"
}

get_8311_hw_ver() {
	fwenv_get_8311 "hw_ver" | head -c 14
}

get_8311_cp_hw_ver_sync() {
	fwenv_get_8311 "cp_hw_ver_sync"
}

set_8311_hw_ver() {
	echo "Setting PON hardware version: $1" | to_console
	_mib_update 256 2 "\"$1\""

	_set_8311_hw_ver "$1"

	local sync_cp_hwver=$(get_8311_cp_hw_ver_sync)
	if [ "$(get_8311_cp_hw_ver_sync)" -eq 1 ] 2>/dev/null; then
		set_8311_cp_hw_ver_sync "$1"
	fi
}

set_8311_cp_hw_ver_sync() {
	echo "Setting PON circuit pack versions to: $1" | to_console
	_mib_update 6 4 "\"$1\""
}

get_8311_equipment_id() {
	fwenv_get_8311 "equipment_id" | head -c 20
}

set_8311_equipment_id() {
	echo "Setting PON equipment ID: $1" | to_console
	_mib_update 257 1 "\"$1\""

	_set_8311_equipment_id "$1"
}

get_8311_lct_mac() {
	if [ ! -f "/tmp/8311-lct-mac" ]; then
		local lct_mac=$(fwenv_get_8311 "lct_mac" | grep -i -E '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$')
		echo "${lct_mac:-$(pon_mac_get lct)}" | strtoupper > "/tmp/8311-lct-mac"
	fi

	cat "/tmp/8311-lct-mac"
}

set_8311_lct_mac() {
	echo "Setting LCT MAC address to: $1" | to_console
	_set_8311_lct_mac "$1"
}

get_8311_iphost_mac() {
	if [ ! -f "/tmp/8311-iphost-mac" ]; then
		local iphost_mac=$(fwenv_get_8311 "iphost_mac" 2>/dev/null | grep -i -E '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$')
		echo "${iphost_mac:-$(pon_mac_get host)}" | strtoupper > "/tmp/8311-iphost-mac"
	fi

	cat "/tmp/8311-iphost-mac"
}

set_8311_iphost_mac() {
	echo "Setting IP host MAC address to: $1" | to_console
	_set_8311_iphost_mac "$1"
}

get_8311_iphost_hostname() {
	fwenv_get_8311 "iphost_hostname" | head -c 25
}

set_8311_iphost_hostname() {
	[ -n "$1" ] && echo "Setting PON IP host hostname to: $1" | to_console
	echo "$1" > "/tmp/8311-iphost-hostname"
}

get_8311_iphost_domain() {
	fwenv_get_8311 "iphost_domain" | head -c 25
}

set_8311_iphost_domain() {
	[ -n "$1" ] && echo "Setting PON IP host domain name to: $1" | to_console
	echo "$1" > "/tmp/8311-iphost-domainname"
}

get_8311_lct_vlan() {
	local lct_vlan=$(($(fwenv_get_8311 "lct_vlan" "0"))) 2>/dev/null
	[ -n "$lct_vlan" ] && [ "$lct_vlan" -ge 0 ] && [ "$lct_vlan" -le 4095 ] && echo "$lct_vlan" || echo "0"
}

set_8311_lct_vlan() {
	echo "Setting LCT VLAN: $1" | to_console
}

get_8311_ipaddr() {
	[ -f "/tmp/8311-ipaddr" ] || { fwenv_get_8311 "ipaddr" | ipv4 || echo "192.168.11.1"; } > "/tmp/8311-ipaddr"

	cat "/tmp/8311-ipaddr"
}

set_8311_ipaddr() {
	echo "Setting LCT IP address: $1" | to_console
	_set_8311_ipaddr "$1"
}

get_8311_netmask() {
	[ -f "/tmp/8311-netmask" ] || { fwenv_get_8311 "netmask" | ipv4 || echo "255.255.255.0"; } > "/tmp/8311-netmask"

	cat "/tmp/8311-netmask"
}

set_8311_netmask() {
	echo "Setting LCT netmask: $1" | to_console
	_set_8311_netmask "$1"
}

get_8311_gateway() {
	[ -f "/tmp/8311-gateway" ] || { fwenv_get_8311 "gateway" | ipv4 || get_8311_ipaddr; } > "/tmp/8311-gateway"

	cat "/tmp/8311-gateway"
}

set_8311_gateway() {
	echo "Setting LCT gateway: $1" | to_console
	_set_8311_gateway "$1"
}

get_8311_dns_server() {
	[ -f "/tmp/8311-dns" ] || fwenv_get_8311 "dns_server" | ipv4 > "/tmp/8311-dns"

	cat "/tmp/8311-dns"
}

set_8311_dns_server() {
	echo "Setting LCT dns: $1" | to_console
}

get_8311_https_redirect() {
	fwenv_get_8311 'https_redirect' '1'
}

get_8311_loid() {
	fwenv_get_8311 "loid" | head -c 24
}

set_8311_loid() {
	echo "Setting PON Logical ONU ID to: $1" | to_console
	uci -q set "omci.default.loid"="$1"
	uci -q commit "omci"
}

get_8311_lpwd() {
	fwenv_get_8311 "lpwd" | head -c 12
}

set_8311_lpwd() {
	echo "Setting PON Logical Password to: $1" | to_console
	uci -q set "omci.default.lpwd"="$1"
	uci -q commit "omci"
}

get_8311_ethtool() {
	fwenv_get_8311 "ethtool_speed"
}

set_8311_ethtool() {
	echo "Setting ethtool speed parameters: $1" | to_console
	ethtool -s eth0_0 $1
}

get_8311_root_pwhash() {
	fwenv_get_8311 "root_pwhash" | grep -E '^\$[0-9a-z]+\$.+\$[A-Za-z0-9./]+$'
}

set_8311_root_pwhash() {
	echo "Setting root password hash: $1" | to_console
	HASH=$(echo "$1" | sed 's#/#\\/#g')
	sed -r "s/(root:)([^:]*)(:.+)/\1${HASH}\3/g" -i /etc/shadow
}

get_8311_pon_slot() {
	fwenv_get_8311 "pon_slot" | grep -E '^[0-9]+$'
}

set_8311_pon_slot() {
	if [ "$1" -gt "1" ] 2>/dev/null && [ "$1" -le "254" ]; then
		echo "Setting PON slot to: $1" | to_console

		local MIB_FILE=$(_mib_file)
		local PON_SLOT_HEX=$(printf '%.2x\n' "$1")
		sed -r "s/^(277\s+(\S+\s+){6})0x01/\10x${PON_SLOT_HEX}/g" -i "$MIB_FILE"
		sed -r "s/^(5|6)\s+0x0101/\1 0x01${PON_SLOT_HEX}/g" -i "$MIB_FILE"
		sed -r "s/^(([?!]\s+)?\d+)\s+0x0101/\1 0x${PON_SLOT_HEX}01/g" -i "$MIB_FILE"
	fi
}

get_8311_hostname() {
	fwenv_get_8311 "hostname"
}

set_8311_hostname() {
	echo "Setting system hostname to: $1" | to_console
	echo "$1" > "/proc/sys/kernel/hostname"
}

get_8311_lang() {
	local lang=$(fwenv_get_8311 "lang" "auto")
	local LANG=$(echo "$lang" | tr '_' '-')
	[ "$lang" = "auto" ] || [ "$lang" = "en" ] || [ -f "/usr/lib/lua/luci/i18n/8311.$LANG.lmo" ] && echo "$lang" || echo "auto"
}

set_8311_lang() {
	echo "Setting LuCI language to: $1" | to_console
}

get_8311_ping_host() {
	if [ ! -f "/tmp/8311-ping-host" ]; then
		local PING_HOST=$(fwenv_get_8311 "ping_ip" | ipv4)

		echo "${PING_HOST:-$(get_8311_default_ping_host)}" > "/tmp/8311-ping-host"
	fi

	cat "/tmp/8311-ping-host"
}

get_8311_default_ping_host() {
	local ipaddr=$(get_8311_ipaddr)
	local netmask=$(get_8311_netmask)
	local gateway=$(get_8311_gateway)

	if [ "$ipaddr" != "$gateway" ]; then
		echo "$gateway"
	else
		IFS='.' read -r i1 i2 i3 i4 <<IPADDR
${ipaddr}
IPADDR
		IFS='.' read -r m1 m2 m3 m4 <<NETMASK
${netmask}
NETMASK

		# calculate the 2nd usable ip of the range (1st is the stick)
		printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$(((i4 & m4) + 2))"
	fi
}


get_8311_module_type() {
	if [ ! -f "/tmp/8311-module-type" ]; then
		local FLASH_VOLTS=$(dmesg | grep -E "nand:.+ NAND" | grep -o -E ' \d,\dv ' | awk '{print $1}' | tr ',' '.')
		local MTDPARTS=$(fwenv_get mtdparts)
		local SFP_HASH=$(head -c 56 /sys/class/pon_mbox/pon_mbox0/device/eeprom51 | sha256sum | awk '{print $1}')

		local MODULE_TYPE='bfw'
		if [ "$SFP_HASH" = "d28ab047c3574a085ee78f087ad8ab96ae3a75f4bc3ee8c286fae6fa374b0055" ]; then
			MODULE_TYPE='bfw'
		elif [ "$SFP_HASH" = "cbd13cd3cea10e799c3ae93733f0ab5d7f1f3f48598111164e46634b2aaccb40" ]; then
			MODULE_TYPE='potron'
		# Full Vision FV-NS10S
		elif [ "$SFP_HASH" =  "e5804f95828218c3ed61ce649bfdc9ed7eb41364a81ad900a08050e3fc77b21d" ]; then
			MODULE_TYPE='fullvision'
		elif [ "$FLASH_VOLTS" = "3.3v" ] &&
			 [ "$MTDPARTS" = 'mtdparts=nand.0:1m(uboot),256k(ubootconfigA),256k(ubootconfigB),256k(gphyfirmware),1m(calibration),16m(bootcore),108m(system_sw),-(res)' ]; then
			MODULE_TYPE='potron'
		fi

		echo "$MODULE_TYPE" > "/tmp/8311-module-type"
	fi

	cat "/tmp/8311-module-type"
}

get_8311_base_mac() {
	if [ ! -f "/tmp/8311-base-mac" ]; then
		local serial=$(dd if=/sys/class/pon_mbox/pon_mbox0/device/eeprom50 bs=1 skip=68 count=12 2>/dev/null)
		local suffix=$(echo "$serial" | tail -c 7 | filterhex)
		[ -z "$suffix" ] && suffix=$(echo -n "$serial" | sha256sum | head -c 6 | strtoupper)

		{ echo -n "10:B3:6F"; echo "$suffix" | sed -r 's/(..)/:\1/g'; } > "/tmp/8311-base-mac"
	fi

	cat "/tmp/8311-base-mac"
}

get_8311_timezone() {
	local TZ=$(fwenv_get_8311 "timezone" | sed 's/ /_/g')
	[ -f "/usr/share/zoneinfo/$TZ" ] || return 1

	echo "$TZ" | sed 's/_/ /g'
}

get_8311_ntp_servers() {
	fwenv_get_8311 "ntp_servers"
}

active_fwbank() {
	grep -E -o '\brootfsname=rootfs[AB]\b' /proc/cmdline | grep -E -o '[AB]$'
}

inactive_fwbank() {
	local active_bank=$(active_fwbank)
	if [ "$active_bank" = "A" ]; then
		echo "B"
	elif [ "$active_bank" = "B" ]; then
		echo "A"
	else
		return 1
	fi

	return 0
}

get_8311_sfp_vendor() {
	fwenv_get_8311 "sfp_vendor" | head -c 16
}

get_8311_sfp_oui() {
	fwenv_get_8311 "sfp_oui" | grep -Ei '^[0-9a-f]{2}(:[0-9a-f]{2}){2}$'
}

get_8311_sfp_partno() {
	fwenv_get_8311 "sfp_partno" | head -c 16
}

get_8311_sfp_rev() {
	fwenv_get_8311 "sfp_rev" | head -c 4
}

get_8311_sfp_serial() {
	fwenv_get_8311 "sfp_serial" | head -c 16
}

get_8311_sfp_date() {
	fwenv_get_8311 "sfp_date" | head -c 8
}

get_8311_sfp_vendordata() {
	fwenv_get_8311 "sfp_vendordata" | head -c 32
}
