#!/bin/sh /etc/rc.common

_lib_8311 2>/dev/null || . /lib/8311.sh

START=60

SNMPD="/usr/sbin/snmpd"
SNMPD_CONF="/var/run/8311-snmpd.conf"
SNMPD_PID="/var/run/8311-snmpd.pid"

generate_config() {
	local community=$(fwenv_get_8311 "snmp_community" "public" | head -c 32 | tr -cd 'A-Za-z0-9._-')
	[ -n "$community" ] || community="public"
	local location=$(fwenv_get_8311 "snmp_location" | head -c 128 | tr -cd 'A-Za-z0-9 ._,()/:@+-')
	local contact=$(fwenv_get_8311 "snmp_contact" | head -c 128 | tr -cd 'A-Za-z0-9 ._,()/:@+-')

	local FW_VERSION FW_REVISION FW_VARIANT
	[ -f /etc/8311_version ] && . /etc/8311_version

	{
		echo "agentaddress UDP:161,TCP:161"
		echo "sysDescr 8311 Community Firmware ${FW_VERSION:-unknown} (${FW_REVISION:-unknown}) [${FW_VARIANT:-unknown}] on WAS-110"
		[ -n "$location" ] && echo "sysLocation $location"
		[ -n "$contact" ] && echo "sysContact $contact"
		echo "rocommunity $community"
		echo ""
		echo "# Hardware sensors via the standard ENTITY-MIB / ENTITY-SENSOR-MIB (RFC 3433)"
		echo "pass_persist .1.3.6.1.2.1.47 /usr/sbin/8311-snmp-sensors.sh .1.3.6.1.2.1.47"
		echo "pass_persist .1.3.6.1.2.1.99 /usr/sbin/8311-snmp-sensors.sh .1.3.6.1.2.1.99"
		echo ""
		echo "# PON specific values via the NET-SNMP-EXTEND-MIB"
		local v
		for v in ploam-state rx-power-dbm tx-power-dbm active-bank pon-mode module-type fw-version; do
			echo "extend $v /usr/sbin/8311-snmp-extend.sh $v"
		done
	} > "$SNMPD_CONF"
}

start() {
	[ -x "$SNMPD" ] || return 0

	stop

	SNMP_EN=$(fwenv_get_8311 "snmp" "0")
	if ! { [ "$SNMP_EN" -eq "1" ] 2>/dev/null; }; then
		return 0
	fi

	generate_config
	echo "Starting SNMP daemon, set fwenv 8311_snmp to 0 to disable" | to_console
	"$SNMPD" -C -c "$SNMPD_CONF" -p "$SNMPD_PID" -Lsd
}

stop() {
	[ -f "$SNMPD_PID" ] && kill "$(cat "$SNMPD_PID")" 2>/dev/null
	rm -f "$SNMPD_PID"
	killall snmpd 2>/dev/null
	return 0
}
