#!/bin/sh

pon_hash() {
	/root/8311-detect-config.sh -H
}

FIX_ENABLED=$(fw_printenv -n 8311_fix_vlans 2>/dev/null)
if [ "$FIX_ENABLED" -eq 0 ] 2>/dev/null; then
	exit 0
fi

LAST_HASH=""
while true ; do
	HASH=$(pon_hash)
	if [ "$HASH" != "$LAST_HASH" ] && ps | grep -q '/bin/omcid$'; then
		flock /tmp/8311-fix-vlans.lock /root/8311-fix-vlans.sh &>/dev/null && LAST_HASH="$HASH"
	fi

	sleep 5
done
