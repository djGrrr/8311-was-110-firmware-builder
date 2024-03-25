#!/bin/sh
PIN=505


_lib_8311 2>/dev/null || . /lib/8311.sh

GPIO="/sys/class/gpio/gpio${PIN}"
[ -d "$GPIO" ] || echo "$PIN" > "/sys/class/gpio/export"

RX_LOS=$(fwenv_get_8311 "rx_los")
[ "$RX_LOS" -ne 0 ] 2>/dev/null && RX_LOS=true || RX_LOS=false


if $RX_LOS; then
	echo "8311 RX_LOS daemon: start monitoring LOS alarm" | to_console
	while true; do
		LOS_VALUE="$(cat "$GPIO/value")"
		LOS_ALARM=$([ -d "/sys/devices/virtual/net/gem-omci" ] && { pon alarm_status_get 0 | grep -E -o 'alarm_status=\d+' | cut -d= -f2; } || echo "0")

		if [ "$LOS_VALUE" -ne "$LOS_ALARM" ] 2>/dev/null; then
			[ "$LOS_ALARM" -eq 1 ] 2>/dev/null && GPIO_DIR="high" || GPIO_DIR="low"
			echo "8311 RX_LOS daemon: setting RX_LOS pin to $GPIO_DIR" | to_console
			echo "$GPIO_DIR" > "$GPIO/direction"
		fi
		sleep 3
	done
else
	echo "8311 RX_LOS daemon: start disabling RX_LOS" | to_console
	while true; do
		if [ "$(cat "$GPIO/value")" -ne 0 ]; then
			echo "8311 RX_LOS daemon: setting RX_LOS pin to low" | to_console
			echo "low" > "$GPIO/direction"
		fi
		sleep 1
	done
fi
