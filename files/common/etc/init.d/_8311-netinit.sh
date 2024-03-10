#!/bin/sh /etc/rc.common

_lib_8311 2>/dev/null || . /lib/8311.sh

START=26

boot() {
	# fwenv for setting eth0_0 speed settings with ethtool
	ETH_SPEED=$(get_8311_ethtool)
	[ -n "$ETH_SPEED" ] && set_8311_ethtool "$ETH_SPEED"

	# 8311 MOD: ping daemon
	/usr/sbin/8311-pingd.sh &
}
