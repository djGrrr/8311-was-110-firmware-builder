#!/bin/sh
_lib_8311 2>/dev/null || . /lib/8311.sh

echo "8311 Reverse ARP daemon: start monitoring" | to_console
while true; do
	RARP_ENABLED=$(fwenv_get_8311 "reverse_arp" "1")

	myip=$(ip -o -4 a list dev eth0_0_1_lct | pcre2grep -o1 ' inet (\d+\.\d+\.\d+\.\d+)/')
	if [ -n "$myip" ] && [ "$RARP_ENABLED" -ne 0 ] 2>/dev/null && [ "$(cat /sys/class/net/eth0_0_1_lct/carrier 2>/dev/null)" -eq 1 ] 2>/dev/null ; then
		IFS='.' read -r i1 i2 i3 i4 <<IPADDR
${myip}
IPADDR

		tcpdump -lKpenNq -Q 'in' -tt -i 'eth0_0_1_lct' "(arp and arp[7]=1 and arp[24]=$i1 and arp[25]=$i2 and arp[26]=$i3 and arp[27]=$i4) or (dst host $myip)" 2>/dev/null |
		pcre2grep --line-buffered -o1 -o2 -o3 --om-separator ' ' '^(\d+)\.\d+ (\S+) > \S+, \S+, length \d+: (?:.+? tell )?(\d+\.\d+\.\d+\.\d+)' |
		awk '{
	ip = $3
	mac = $2
	time = $1
	if (!macs[ip] || !times[ip] || macs[ip] != mac || (time - times[ip]) > 15) {
		macs[ip] = $2
		times[ip] = $1
		print "ip neigh replace dev eth0_0_1_lct to " ip " lladdr " mac " nud reachable"
	}
}' |
		sh
		sleep 1
	else
		sleep 5
	fi
done
