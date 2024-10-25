#!/bin/sh
omci="/usr/bin/omci_pipe.sh"
pcre="/usr/bin/pcre2grep"

_lib_8311_omci() {
	return 0
}

_lib_int &>/dev/null || . /lib/functions/int.sh
_lib_hexbin &>/dev/null || . /lib/functions/hexbin.sh

mibs() {
	if [ -n "$1" ]; then
		me=$(($1))
		$omci md | $pcre -o1 "^\|\s+${me}\s+\|\s+(\d+)\b"
	else
		$omci md | $pcre -o1 -o2 --om-separator=' ' '^\|\s+(\d+)\s+\|\s+(\d+)\s+'
	fi
}

mib() {
	[ -n "$2" ] || return 1
	$omci meg "$(($1))" "$(($2))"
}

mibattr() {
	[ -n "$3" ] || return 1
	local attr=$(($3)) || return 1
	local data=$(mib "$1" "$2") || return $?

	echo "$data" | $pcre -o1 -M "^(?s)-{79}\n(\s*${attr}\s+.+?)\n-{79}$"
}

mibattrdata() {
	local nl=true
	local hexstr=false
	local me=
	local id=
	local attr=

	while [ $# -gt 0 ]; do
		case "$1" in
			-n)
				nl=false;
			;;
			-x)
				hexstr=true
			;;
			*)
				if [ -z "$me" ]; then
					me="$1"
				elif [ -z "$id" ]; then
					id="$1"
				elif [ -z "$attr" ]; then
					attr="$1"
				else
					return 1
				fi
			;;
		esac
		shift
	done

	local mibattr=$(mibattr "$me" "$id" "$attr") || return $?
	local typesize=$(echo "$mibattr" | head -n1 | $pcre --om-separator ' ' -o1 -o2 '\b(\d+)b\s+(\S+)\s+\S+$')
	local bytes=$(echo "$typesize" | cut -d' ' -f1)
	local type=$(echo "$typesize" | cut -d' ' -f2)

	local sint=false
	[ "$type" = "SINT" ] && sint=true
	if $sint || [ "$type" = "BF" ] || [ "$type" = "ENUM" ] || [ "$type" = "PTR" ] || [ "$type" = "UINT" ]; then
		local int="0x$(echo "$mibattr" | head -n2 | tail -n1 | $pcre -o1 '^((?:\s+0x[0-9a-f]{2,8})+)' | sed -r -e 's/0x//g' -e 's/\s+//g')"
		local inttype="uint"
		$sint && inttype="int"

		local size=$((bytes * 8))

		"$inttype$size" "$int"
	elif [ "$type" = "STR" ] || [ "$type" = "TBL" ]; then
		[ "$type" = "STR" ] && HEAD=-1 || HEAD=-2
		local hexdata=$(echo -n "$mibattr" | head -n $HEAD | tail -n +2 | sed -r -e 's/\s+//g' -e 's/0x//g')
		if [ "$type" = "STR" ]; then
			hexdata=$(echo "$hexdata" | tr -d '\n')
			echo "$hexdata" | { ! $hexstr && hex2str || cat; }
			! $hexstr && $nl && echo
		else
			echo "$hexdata"
		fi
	else
		return 1
	fi
}
