#!/bin/sh

_lib_8311 2>/dev/null || . /lib/8311.sh

pon_hash() {
    {
        ip li                  # 列出所有网络接口
        brctl show            # 显示网桥配置
    } | sha256sum | awk '{print $1}'
}
config_hash() {
	{
		fwenv_get_8311 "us_vlan_id"
		fwenv_get_8311 "us_mc_vlan_id"
		fwenv_get_8311 "ds_mc_tci"
		fwenv_get_8311 "vlan_tag_ops"
		fwenv_get_8311 "igmp_version"
		fwenv_get_8311 "vlan_svc_log"
		fwenv_get_8311 "force_us_vlan_id"
		fwenv_get_8311 "force_me_create"
		fwenv_get_8311 "force_me309_create"
	} | sha256sum | awk '{print $1}'
}

FIX_ENABLED=$(fwenv_get_8311 "fix_vlans" "1")
[ "$FIX_ENABLED" -eq 0 ] 2>/dev/null && exit 0


FIXES=""
[ "$FIX_ENABLED" -eq 1 ] && FIXES="/usr/sbin/8311-fix-vlans.sh"
HOOKCMD=". /lib/8311-vlans-lib.sh && . $HOOK"

LAST_HASH=""
LAST_CFG_HASH=""

echo "8311 VLANs daemon: start monitoring" | to_console
while true ; do
	[ -f "$HOOK" ] && { [ -n "$FIXES" ] && CMD="$FIXES && $HOOKCMD" || CMD="$HOOKCMD"; } || CMD="$FIXES"

	if [ -n "$CMD" ] && [ -d "/sys/devices/virtual/net/gem-omci" ]; then
		HASH=$(pon_hash)
		CFG_HASH=$(config_hash)
		if [ "$HASH" != "$LAST_HASH" ] || [ "$CFG_HASH" != "$LAST_CFG_HASH" ]; then
			echo "8311 VLANs daemon: new configuration detected, ran fix-vlans script." | to_console
			flock /tmp/8311-fix-vlans.lock -c "$CMD" 2>&1
			LAST_HASH="$HASH"
			LAST_CFG_HASH="$CFG_HASH"
		fi
	fi

	sleep 5
done
