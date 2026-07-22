#!/bin/sh
# SNMP pass_persist sub-agent exposing WAS-110 hardware sensors through the
# standard ENTITY-MIB entPhysicalTable (.1.3.6.1.2.1.47) and ENTITY-SENSOR-MIB
# entPhySensorTable (.1.3.6.1.2.1.99, RFC 3433).
#
# Registered in snmpd.conf by /etc/init.d/_8311-snmpd.sh as:
#   pass_persist .1.3.6.1.2.1.47 /usr/sbin/8311-snmp-sensors.sh .1.3.6.1.2.1.47
#   pass_persist .1.3.6.1.2.1.99 /usr/sbin/8311-snmp-sensors.sh .1.3.6.1.2.1.99
#
# entPhysicalIndex assignments:
#   1 - chassis (the WAS-110 module itself)
#   2 - optical transceiver temperature   (celsius)
#   3 - CPU temperature 1                 (celsius)
#   4 - CPU temperature 2                 (celsius)
#   5 - transceiver supply voltage        (volts DC)
#   6 - TX laser bias current             (amperes)
#   7 - TX optical output power           (watts)
#   8 - RX optical input power            (watts)

ROOT="${1:-.1.3.6.1.2.1}"

EEPROM50="/sys/class/pon_mbox/pon_mbox0/device/eeprom50"
EEPROM51="/sys/class/pon_mbox/pon_mbox0/device/eeprom51"
THERMAL1="/sys/class/thermal/thermal_zone0/temp"
THERMAL2="/sys/class/thermal/thermal_zone1/temp"

ENT=".1.3.6.1.2.1.47.1.1.1.1"
SEN=".1.3.6.1.2.1.99.1.1.1"

eeprom50_str() {
	dd if="$EEPROM50" bs=1 skip="$1" count="$2" 2>/dev/null | tr -cd 'A-Za-z0-9 ._-' | sed -e 's/^ *//' -e 's/ *$//'
}

# Static module identity from the SFP A0h EEPROM (SFF-8472)
MFG=$(eeprom50_str 20 16)
MODEL=$(eeprom50_str 40 16)
HWREV=$(eeprom50_str 56 4)
SERIAL=$(eeprom50_str 68 16)

gen_table() {
	TABLE=$(cat <<TABLE_EOF
$ENT.2.1|string|WAS-110 XGS-PON SFP+ module
$ENT.2.2|string|Optical transceiver temperature
$ENT.2.3|string|CPU temperature 1
$ENT.2.4|string|CPU temperature 2
$ENT.2.5|string|Transceiver supply voltage
$ENT.2.6|string|TX laser bias current
$ENT.2.7|string|TX optical output power
$ENT.2.8|string|RX optical input power
$ENT.4.1|integer|0
$ENT.4.2|integer|1
$ENT.4.3|integer|1
$ENT.4.4|integer|1
$ENT.4.5|integer|1
$ENT.4.6|integer|1
$ENT.4.7|integer|1
$ENT.4.8|integer|1
$ENT.5.1|integer|3
$ENT.5.2|integer|8
$ENT.5.3|integer|8
$ENT.5.4|integer|8
$ENT.5.5|integer|8
$ENT.5.6|integer|8
$ENT.5.7|integer|8
$ENT.5.8|integer|8
$ENT.6.1|integer|-1
$ENT.6.2|integer|1
$ENT.6.3|integer|2
$ENT.6.4|integer|3
$ENT.6.5|integer|4
$ENT.6.6|integer|5
$ENT.6.7|integer|6
$ENT.6.8|integer|7
$ENT.7.1|string|was110
$ENT.7.2|string|optic-temperature
$ENT.7.3|string|cpu1-temperature
$ENT.7.4|string|cpu2-temperature
$ENT.7.5|string|supply-voltage
$ENT.7.6|string|tx-bias
$ENT.7.7|string|tx-power
$ENT.7.8|string|rx-power
$ENT.8.1|string|$HWREV
$ENT.11.1|string|$SERIAL
$ENT.12.1|string|$MFG
$ENT.13.1|string|$MODEL
$SEN.1.2|integer|8
$SEN.1.3|integer|8
$SEN.1.4|integer|8
$SEN.1.5|integer|4
$SEN.1.6|integer|5
$SEN.1.7|integer|6
$SEN.1.8|integer|6
$SEN.2.2|integer|9
$SEN.2.3|integer|9
$SEN.2.4|integer|9
$SEN.2.5|integer|8
$SEN.2.6|integer|7
$SEN.2.7|integer|7
$SEN.2.8|integer|7
$SEN.3.2|integer|1
$SEN.3.3|integer|1
$SEN.3.4|integer|1
$SEN.3.5|integer|1
$SEN.3.6|integer|0
$SEN.3.7|integer|1
$SEN.3.8|integer|1
$SEN.4.2|integer|$OPTIC
$SEN.4.3|integer|$CPU1
$SEN.4.4|integer|$CPU2
$SEN.4.5|integer|$VOLT
$SEN.4.6|integer|$BIAS
$SEN.4.7|integer|$TXPWR
$SEN.4.8|integer|$RXPWR
$SEN.5.2|integer|$DDM_OK
$SEN.5.3|integer|$CPU1_OK
$SEN.5.4|integer|$CPU2_OK
$SEN.5.5|integer|$DDM_OK
$SEN.5.6|integer|$DDM_OK
$SEN.5.7|integer|$DDM_OK
$SEN.5.8|integer|$DDM_OK
$SEN.6.2|string|celsius
$SEN.6.3|string|celsius
$SEN.6.4|string|celsius
$SEN.6.5|string|volts DC
$SEN.6.6|string|amperes
$SEN.6.7|string|watts
$SEN.6.8|string|watts
TABLE_EOF
)
}

CACHE_TS=-100
refresh() {
	local now=$(date +%s)
	[ $((now - CACHE_TS)) -lt 5 ] && return
	CACHE_TS=$now

	# CPU temperatures in millidegrees C, converted to tenths of a degree
	CPU1=$(awk '{printf "%d", $1 / 100}' "$THERMAL1" 2>/dev/null)
	CPU2=$(awk '{printf "%d", $1 / 100}' "$THERMAL2" 2>/dev/null)
	CPU1_OK=1; [ -n "$CPU1" ] || { CPU1_OK=2; CPU1=0; }
	CPU2_OK=1; [ -n "$CPU2" ] || { CPU2_OK=2; CPU2=0; }

	# SFP DDM values from the A2h EEPROM (SFF-8472), same offsets used by
	# the LuCI metrics endpoint (8311.tools metrics)
	DDM_OK=2
	OPTIC=0; VOLT=0; BIAS=0; TXPWR=0; RXPWR=0
	eval "$(hexdump -v -s 96 -n 10 -e '10/1 "%u "' "$EEPROM51" 2>/dev/null | awk 'NF == 10 {
		t = $1 * 256 + $2
		if (t >= 32768) t -= 65536
		printf "OPTIC=%d;", t * 10 / 256       # tenths of a degree C
		printf "VOLT=%d;", $3 * 256 + $4       # tenths of a millivolt
		printf "BIAS=%d;", ($5 * 256 + $6) * 2 # microamperes
		printf "TXPWR=%d;", $7 * 256 + $8      # tenths of a microwatt
		printf "RXPWR=%d;", $9 * 256 + $10     # tenths of a microwatt
		printf "DDM_OK=1"
	}')"

	gen_table
}

respond() {
	local mode="$1" oid="$2"
	refresh
	printf '%s\n' "$TABLE" | awk -F'|' -v mode="$mode" -v q="$oid" -v root="$ROOT." '
		function oidcmp(a, b,   x, y, n, m, i) {
			n = split(a, x, "."); m = split(b, y, ".")
			for (i = 1; i <= n && i <= m; i++) {
				if (x[i] + 0 < y[i] + 0) return -1
				if (x[i] + 0 > y[i] + 0) return 1
			}
			if (n < m) return -1
			if (n > m) return 1
			return 0
		}
		index($1 ".", root) != 1 { next }
		(mode == "get" && $1 == q) || (mode == "getnext" && oidcmp($1, q) > 0) {
			print $1; print $2; print $3
			found = 1
			exit
		}
		END { if (!found) print "NONE" }
	'
}

while read -r cmd; do
	case "$cmd" in
		PING)
			echo "PONG"
		;;
		get|getnext)
			read -r oid || exit 0
			case "$oid" in
				.*) ;;
				*) oid=".$oid" ;;
			esac
			respond "$cmd" "$oid"
		;;
		set)
			read -r oid || exit 0
			read -r value || exit 0
			echo "not-writable"
		;;
		"")
			exit 0
		;;
	esac
done
