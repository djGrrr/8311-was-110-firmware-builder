#!/bin/sh /etc/rc.common
# Copyright (C) 2013 OpenWrt.org
# Copyright (C) 2013 lantiq.com
# Copyright (C) 2020 Intel Corporation
# Copyright (C) 2021 - 2022 MaxLinear, Inc.

# define default
pon_sgmii_mode() {
	echo 0
}

. $IPKG_INSTROOT/lib/pon.sh
. $IPKG_INSTROOT/lib/functions.sh

START=62
SFP_I2C_BINARY=/usr/bin/sfp_i2c

sfp_i2c() {
	#echo "sfp_i2c $*"
	$SFP_I2C_BINARY $*
}

# don't used wrapper above to ensure correct quoting of string
set_string()  {
	$SFP_I2C_BINARY -i $1 -s "$2"
}

set_sfp_string() {
	local index=$(($1))
	local length=$(($2))
	local hex=$(echo -n "$3" | xxd -p -l $length -c 1)
	local end=$((index + length))

	# write out string
	for v in $hex; do
		$SFP_I2C_BINARY -i "$index" -w "0x$v" || return $?
		index=$((index + 1))
	done

	# pad with NULLs
	while [ "$index" -lt "$end" ]; do
		$SFP_I2C_BINARY -i "$index" -w 0 || return $?
		index=$((index + 1))
	done

	return 0
}

vendor_config() {
	local name
	local partno
	local revision
	local datecode
	local oui
	local oui_hex
	local vendordata

	config_get name default vendor_name
	config_get partno default vendor_partno
	config_get revision default vendor_rev
	config_get datecode default datecode
	config_get oui default vendor_oui
	config_get vendordata default vendor_data

	[ -n "$name" ] && set_string 0 "$name"
	[ -n "$partno" ] && set_string 1 "$partno"
	[ -n "$revision" ] && set_string 2 "$revision"
	[ -n "$datecode" ] && set_string 4 "$datecode"
	[ -n "$vendordata" ] && set_sfp_string 96 32 "$vendordata"

	if [ -n "$oui" ]; then
		oui_hex=$(echo $oui | awk 'BEGIN{FS=":"} {printf "0x%2s%2s%2s",$1,$2,$3}')
		$SFP_I2C_BINARY -i 36 -w $oui_hex -4 -m 0x00FFFFFF
	fi
}

serialnumber_config() {
	local nSerial

	config_get nSerial default serial_no
	[ -n "$nSerial" ] && set_string 3 "$nSerial"
}

bitrate_config() {
	local nBitrate

	case $(pon_sgmii_mode) in
	2 | 5) # sgmii_fast or sgmii_fast_auto
		nBitrate=25
		;;
	6) # 10G
		nBitrate=100
		;;
	*) # default mode
		nBitrate=10
		;;
	esac

	sfp_i2c -1 -l 1 -i 12 -w $nBitrate
}

eeprom_addr_get() {
	local num=$1
	local def=$2
	local section=${3}
	local addr

	addr=$(fw_printenv -n sfp_i2c_addr_eeprom_$num 2>&-)
	if [ -z "$addr" ]; then
		config_get addr $section addr_eeprom_$num $def
	fi

	echo $addr
}

eeprom_addr_config() {
	local addr
	local section=${1:-default}

	addr=$(eeprom_addr_get 0 0x50 $section)
	[ -n "$addr" ] && sfp_i2c -b $addr

	addr=$(eeprom_addr_get 1 0x51 $section)
	[ -n "$addr" ] && sfp_i2c -B $addr
}

default_sfp_init() {
	local eeprom

	config_load sfp_eeprom

	# reset to default values, if no init file exists
	[ -e /lib/firmware/sfp_eeprom0_hack.bin ] || sfp_i2c -d yes
	vendor_config
	serialnumber_config
	bitrate_config

	# clone the initial DMI configuration values from the physical EEPROM
	local index=256
	for x in $(head -c 95 /sys/class/pon_mbox/pon_mbox0/device/eeprom51 | xxd -p -c 1); do
		sfp_i2c -i $index -w 0x$x
		index=$((index + 1))
	done

	# configure I2C EEPROM addresses
	eeprom_addr_config

	# write protection: 0x50 / 0 - 95
	sfp_i2c -i 0 -l 96 -p 1
	# write protection: 0x51 / 0 - 127
	sfp_i2c -i 256 -l 128 -p 1

	# activate write protection for dedicated fields
	# 0x51 / 110, writable bits 3 & 6
	sfp_i2c -i 366 -p 2 -m 0xB7
	# 0x51 / 118, writable bits 0 & 3
	sfp_i2c -i 374 -p 2 -m 0xF6

	# check which EEPROM should be the current one (for legacy driver)
	config_get eeprom default eeprom 0
	# set current EEPROM
	sfp_i2c -e $eeprom
}

boot() {
	local enable_bridge

	# check if sfp_i2c driver is available
	if [ ! -c /dev/sfp_eeprom0 ]; then
		disable
		return 0
	fi

	config_load sfp_eeprom
	config_get_bool enable_bridge factory_bridge enable 0

	# do default init if factory-bridge is disabled
	[ "$enable_bridge" = "0" ] && default_sfp_init

	start "$@"
}

start_dmi_monitoring() {
	local eeprom_dmi
	local eeprom_serial_id
	local sync0
	local sync1

	config_load optic
	config_get eeprom_dmi sfp_eeprom dmi
	config_get eeprom_serial_id sfp_eeprom serial_id

	[ -n "$eeprom_dmi" ] && sync0="-T $eeprom_dmi"
	[ -n "$eeprom_serial_id" ] && sync1="-S $eeprom_serial_id"

	# don't use wrapper to avoid leaving this script active in background
	$SFP_I2C_BINARY -a $sync0 $sync1 > /dev/console &

	sleep 1
	# enable I2C processing
	sfp_i2c -P enable
}

start_factory_bridge() {
	local pmd_0
	local pmd_1
	local sync_0
	local sync_1

	config_load sfp_eeprom
	config_get pmd_0 factory_bridge pmd_0
	config_get pmd_1 factory_bridge pmd_1
	[ -n "$pmd_0" ] && sync_0="-S $pmd_0"
	[ -n "$pmd_1" ] && sync_1="-T $pmd_1"

	# configure I2C EEPROM addresses
	eeprom_addr_config 'factory_bridge'
	# disable write protection to see and forward all writes
	sfp_i2c -i 0 -l 256 -p 0
	sfp_i2c -i 256 -l 256 -p 0

	# don't use wrapper to avoid leaving this script active in background
	$SFP_I2C_BINARY -A $sync_0 $sync_1 > /dev/console &
}

start() {
	local enable_bridge

	config_load sfp_eeprom
	config_get_bool enable_bridge factory_bridge enable 0

	case "$enable_bridge" in
	"0")
		start_dmi_monitoring
		;;
	"1")
		start_factory_bridge
		;;
	esac
}

stop() {
	# disable I2C processing
	sfp_i2c -P disable
	killall -TERM sfp_i2c
}

debug() {
	killall -USR1 sfp_i2c
}

peek() {
	killall -USR2 sfp_i2c
}

EXTRA_COMMANDS="debug peek"
EXTRA_HELP=\
"	debug	toggle debug output of monitoring daemon
	peek	trigger single debug output of monitoring daemon"
