#!/bin/sh
# Helper providing PON specific values to the SNMP daemon through the
# standard NET-SNMP-EXTEND-MIB (nsExtendOutput1Line), registered in
# snmpd.conf by /etc/init.d/_8311-snmpd.sh

_lib_8311 2>/dev/null || . /lib/8311.sh

EEPROM51="/sys/class/pon_mbox/pon_mbox0/device/eeprom51"

ddm_power_dbm() {
	# $1 = byte offset of a 16 bit optical power value (units of 0.1 uW)
	# in the SFP A2h EEPROM, output in dBm (-99.99 when no signal)
	hexdump -v -s "$1" -n 2 -e '2/1 "%u "' "$EEPROM51" 2>/dev/null | awk '
		NF == 2 {
			mw = ($1 * 256 + $2) / 10000
			if (mw <= 0) { print "-99.99"; exit }
			printf "%.2f\n", 10 * log(mw) / log(10)
		}'
}

case "$1" in
	ploam-state)
		pon psg 2>/dev/null | sed -nre 's/.*current=([0-9]+).*/\1/p' | head -n1 | grep . || echo 0
	;;
	rx-power-dbm)
		ddm_power_dbm 104
	;;
	tx-power-dbm)
		ddm_power_dbm 102
	;;
	active-bank)
		active_fwbank
	;;
	pon-mode)
		get_8311_pon_mode
	;;
	module-type)
		get_8311_module_type
	;;
	fw-version)
		[ -f /etc/8311_version ] && . /etc/8311_version
		echo "${FW_VERSION:-unknown} (${FW_REVISION:-unknown}) [${FW_VARIANT:-unknown}]"
	;;
	*)
		echo "Usage: $0 ploam-state|rx-power-dbm|tx-power-dbm|active-bank|pon-mode|module-type|fw-version" >&2
		exit 1
	;;
esac
