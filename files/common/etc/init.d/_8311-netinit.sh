#!/bin/sh /etc/rc.common

_lib_8311 2>/dev/null || . /lib/8311.sh

START=26

boot() {
	# fwenv for setting eth0_0 speed settings with ethtool
	ETH_SPEED=$(get_8311_ethtool)
	[ -n "$ETH_SPEED" ] && set_8311_ethtool "$ETH_SPEED"

	# LCT IP Address
	set_8311_ipaddr "$(get_8311_ipaddr)"

	# LCT Netmask
	set_8311_netmask "$(get_8311_netmask)"

	# LCT Gateway
	set_8311_gateway "$(get_8311_gateway)"

	# LCT MAC
	set_8311_lct_mac "$(get_8311_lct_mac)"

	# IP Host MAC
	set_8311_iphost_mac "$(get_8311_iphost_mac)"

	# ping daemon
	/usr/sbin/8311-pingd.sh &
}
