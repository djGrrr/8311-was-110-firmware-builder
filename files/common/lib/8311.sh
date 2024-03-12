#!/bin/sh

_lib_8311() {
	return 0
}

. "/lib/pon.sh"
. "/lib/8311_backend.sh"

lib_hexbin 2>/dev/null || . /lib/functions/hexbin.sh

to_console() {
	tee -a /dev/console | logger -t "8311" -p daemon.info
}

strtoupper() {
	tr '[a-z]' '[A-Z]'
}

strtolower() {
	tr '[A-Z]' '[a-z]'
}

_8311_check_persistent_root() {
	# Remove persistent root
	PERSIST_ROOT=$(fw_printenv -n 8311_persist_root 2>/dev/null)
	if ! { [ "$PERSIST_ROOT" -eq "1" ] 2>/dev/null; }; then
		echo "8311_persist_root not enabled, checking bootcmd..." | to_console
		BOOTCMD=$(fw_printenv -n bootcmd 2>/dev/null)
		if ! { echo "$BOOTCMD" | grep -Eq '^\s*run\s+ubi_init\s*;\s*ubi\s+remove\s+rootfs_data\s*;\s*run\s+flash_flash\s*$'; }; then
			echo "Resetting bootcmd to default value and rebooting, set fwenv 8311_persist_root=1 to avoid this" | tee -a /dev/console

			fw_setenv bootcmd "run ubi_init; ubi remove rootfs_data; run flash_flash"
			fw_setenv bootcmd "run ubi_init; ubi remove rootfs_data; run flash_flash"

			sync
			reboot
			sleep 15
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

get_8311_gpon_sn() {
	fw_printenv -n "8311_gpon_sn" 2>/dev/null | grep -E '^[A-Za-z0-9]{4}[A-Fa-f0-9]{8}$'
}

set_8311_gpon_sn() {
	echo "Setting PON SN: $1" | to_console
	_set_8311_gpon_sn "$1"
}

get_8311_device_sn() {
	fw_printenv -n "8311_device_sn" 2>/dev/null
}

set_8311_device_sn() {
#	echo "Setting device SN to: $1" | to_console
	_set_8311_device_sn "$1"
}

get_8311_vendor_id() {
	fw_printenv -n "8311_vendor_id" 2>/dev/null | grep -E '^[A-Za-z0-9]{4}$'
}

set_8311_vendor_id() {
	echo "Setting PON vendor ID: $1" | to_console
	_mib_update 6 5 "\"$1\""
	_mib_update 256 1 "\"$1\""

	_set_8311_vendor_id "$1"
}

get_8311_mib_file() {
	local tmp=$(fw_printenv -n 8311_mib_file 2>/dev/null)
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

get_8311_reg_id_hex() {
	{ { fw_printenv -n "8311_reg_id_hex" | hex2str; } || echo -n "$(fw_printenv -n 8311_reg_id)"; cat /dev/zero; } 2>/dev/null | head -c 36 | str2hex | strtoupper
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
	
	{ fw_printenv -n "8311_sw_ver$i1" || fw_printenv -n "8311_sw_ver" || fw_printenv -n "8311_sw_ver$i2"; } 2>/dev/null | head -c 14
}

set_8311_sw_ver() {
	[ "$1" != "A" ] && [ "$1" != "B" ] && [ -z "$2" ] && return 1

	echo "Setting PON image $1 version: $2" | to_console
	_set_8311_sw_ver "$1" "$2"
}

get_8311_hw_ver() {
	fw_printenv -n "8311_hw_ver" 2>/dev/null | head -c 14
}

get_8311_cp_hw_ver_sync() {
	fw_printenv -n 8311_cp_hw_ver_sync 2>/dev/null
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
	fw_printenv -n 8311_equipment_id 2>/dev/null | head -c 20
}

set_8311_equipment_id() {
	echo "Setting PON equipment ID: $1" | to_console
	_mib_update 257 1 "\"$1\""

	_set_8311_equipment_id "$1"
}

get_8311_lct_mac() {
	if [ ! -f "/tmp/8311-lct-mac" ]; then
		local lct_mac=$(fw_printenv -n 8311_lct_mac 2>/dev/null | grep -i -E '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$')
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
		local iphost_mac=$(fw_printenv -n 8311_iphost_mac 2>/dev/null | grep -i -E '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$')
		echo "${iphost_mac:-$(pon_mac_get host)}" | strtoupper > "/tmp/8311-iphost-mac"
	fi

	cat "/tmp/8311-iphost-mac"
}

set_8311_iphost_mac() {
	echo "Setting IP host MAC address to: $1" | to_console
	_set_8311_iphost_mac "$1"
}

get_8311_iphost_hostname() {
	fw_printenv -n 8311_iphost_hostname 2>/dev/null | head -c 25
}

set_8311_iphost_hostname() {
	[ -n "$1" ] && echo "Setting PON IP host hostname to: $1" | to_console
	echo "$1" > "/tmp/8311-iphost-hostname"
}

get_8311_iphost_domain() {
	fw_printenv -n 8311_iphost_domain 2>/dev/null | head -c 25
}

set_8311_iphost_domain() {
	[ -n "$1" ] && echo "Setting PON IP host domain name to: $1" | to_console
	echo "$1" > "/tmp/8311-iphost-domainname"
}

get_8311_ipaddr() {
	[ -f "/tmp/8311-ipaddr" ] || { fw_printenv -n 8311_ipaddr 2>/dev/null || echo "192.168.11.1"; } > "/tmp/8311-ipaddr"

	cat "/tmp/8311-ipaddr"
}

get_8311_netmask() {
	[ -f "/tmp/8311-netmask" ] || { fw_printenv -n 8311_netmask 2>/dev/null || echo "255.255.255.0"; } > "/tmp/8311-netmask"

	cat "/tmp/8311-netmask"
}

get_8311_gateway() {
	[ -f "/tmp/8311-gateway" ] || { fw_printenv -n 8311_gateway 2>/dev/null || get_8311_ipaddr; } > "/tmp/8311-gateway"

	cat "/tmp/8311-gateway"
}

get_8311_loid() {
	fw_printenv -n 8311_loid 2>/dev/null | head -c 24
}

set_8311_loid() {
	echo "Setting PON Logical ONU ID to: $1" | to_console
	uci -q set "omci.default.loid"="$1"
	uci -q commit "omci"
}

get_8311_lpwd() {
	fw_printenv -n 8311_lpwd 2>/dev/null | head -c 12
}

set_8311_lpwd() {
	echo "Setting PON Logical Password to: $1" | to_console
	uci -q set "omci.default.lpwd"="$1"
	uci -q commit "omci"
}

get_8311_ethtool() {
	fw_printenv -n 8311_ethtool_speed 2>/dev/null
}

set_8311_ethtool() {
	echo "Setting ethtool speed parameters: $1" | to_console
	ethtool -s eth0_0 $1
}

get_8311_root_pwhash() {
	fw_printenv -n 8311_root_pwhash 2>/dev/null | sed 's#/#\\/#g'
}

set_8311_root_pwhash() {
	echo "Setting root password hash: $1" | to_console
	sed -r "s/(root:)([^:]*)(:.+)/\1${1}\3/g" -i /etc/shadow
}

get_8311_pon_slot() {
	fw_printenv -n 8311_pon_slot 2>/dev/null | grep -E '^[0-9]+$'
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

get_8311_ping_host() {
	if [ ! -f "/tmp/8311-ping-host" ]; then
		local PING_HOST=$(fw_printenv -n 8311_ping_ip 2>/dev/null)

		if [ -z "$PING_HOST" ]; then
			local ipaddr=$(get_8311_ipaddr)
			local netmask=$(get_8311_netmask)
			local gateway=$(get_8311_gateway)

			if [ "$ipaddr" != "$gateway" ]; then
				echo "$gateway" > "/tmp/8311-ping-host"
			else
				IFS='.' read -r i1 i2 i3 i4 <<IPADDR
${ipaddr}
IPADDR
				IFS='.' read -r m1 m2 m3 m4 <<NETMASK
${netmask}
NETMASK

				# calculate the 2nd usable ip of the range (1st is the stick)
				printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$(((i4 & m4) + 2))" > "/tmp/8311-ping-host"
			fi
		fi
	fi

	cat "/tmp/8311-ping-host"
}


get_8311_module_type() {
	if [ ! -f "/tmp/8311-module-type" ]; then
		local SFP_HASH=$(head -c 56 /sys/class/pon_mbox/pon_mbox0/device/eeprom51 | sha256sum | awk '{print $1}')
		local MODULE_TYPE='bfw'
		if [ "$SFP_HASH" = "cbd13cd3cea10e799c3ae93733f0ab5d7f1f3f48598111164e46634b2aaccb40" ]; then
			MODULE_TYPE='potron'
		elif [ "$SFP_HASH" = "d28ab047c3574a085ee78f087ad8ab96ae3a75f4bc3ee8c286fae6fa374b0055" ]; then
			MODULE_TYPE='bfw'
		fi

		echo "$MODULE_TYPE" > "/tmp/8311-module-type"
	fi

	cat "/tmp/8311-module-type"
}

get_8311_base_mac() {
	local serial=$(dd if=/sys/class/pon_mbox/pon_mbox0/device/eeprom50 bs=1 skip=68 count=12 2>/dev/null)
	local suffix=$(echo "$serial" | tail -c 7 | filterhex)
	[ -z "$suffix" ] && suffix=$(echo -n "$serial" | sha256sum | head -c 6 | strtoupper)

	echo -n "10:B3:6F"

	echo "$suffix" | sed -r 's/(..)/:\1/g'
}