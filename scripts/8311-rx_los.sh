#!/bin/sh

PIN=505
GPIO="/sys/class/gpio/gpio${PIN}"
[ -d "$GPIO" ] || echo "$PIN" > "/sys/class/gpio/export"

RX_LOS=$(fw_printenv -n 8311_rx_los 2>/dev/null)
if ! [ "$RX_LOS" -eq 0 ] 2>/dev/null; then
	exit 0
fi

while true; do
    [ "$(cat "$GPIO/value")" -eq 0 ] || echo "low" > "$GPIO/direction"
    sleep 1
done
