#!/bin/sh
HEADER=true
TABLE=false

_help() {
	printf -- 'Tool for decoding the extended VLAN tables\n\n'

	printf -- 'Usage %s [options]\n\n' "$0"

	printf -- 'Options:\n'
	printf -- '-t --table\tOutput table version instead of user-friendly version\n'
	printf -- '-n --no-header\tDo not output informational headers\n'

	printf -- '-h --help\tThis help text\n'

	exit $1
}

while [ $# -gt 0 ]; do
	case "$1" in
		-t|--table)
			TABLE=true
		;;
		-n|--no-header)
			HEADER=false
		;;
		-h|--help)
			_help 0
		;;

		*)
			_help 1
		;;
	esac
	shift
done

dir() {
	[ "$1" = "i" ] && echo "inner" || echo "outer"
}

odir() {
	[ "$i" = "i" && echo "outer" || echo "inner"
}

output_priority() {
	local dir=$(dir "$1")

	if [ "$2" -le  7 ]; then
		echo "$2"
	elif [ "$2" -eq 8 ]; then
		echo -e "8\t(Do not filter on the $dir priority)"
	elif [ "$2" -eq 14 ]; then
		if [ "$dir" = "inner" ]; then
			echo -e "14\t(Default filter when no other one-tag rule applies)"
		else
			echo -e "14\t(Default filter when no other two-tag rule applies)"
		fi
	elif [ "$2" -eq 15 ]; then
		if [ "$dir" = "inner" ]; then
			echo -e "15\t(No-tag rule; ignore all other VLAN tag filter fields)"
		else
			echo -e "15\t(Not a double-tag rule; ignore all other outer tag filter fields)"
		fi
	else
		echo -e "$2\t(Reserved)"
	fi
}

output_treat_priority() {
	local dir=$(dir "$1")

	if [ "$2" -le  7 ]; then
		echo "$2"
	elif [ "$2" -eq 8 ]; then
		echo -e "8\t(Copy from the inner priority of received frame)"
	elif [ "$2" -eq 9 ]; then
		echo -e "9\t(Copy from the outer priority of received frame)"
	elif [ "$2" -eq 10 ]; then
		echo -e "10\t(Derive priority based on DSCP to P-bit mapping)"
	elif [ "$2" -eq 15 ]; then
		echo -e "15\t(Do not add an $dir tag)"
	else
		echo -e "$2\t(Reserved)"
	fi
}

output_vid() {
	local dir=$(dir "$1")

	if [ "$2" -lt 4095 ]; then
		echo "$2"
	elif [ "$2" -eq 4096 ]; then
		echo -e "4096\t(Do not filter on the $dir VID)";
	else
		echo -e "$2\t(Reserved)";
	fi
}

output_treat_vid() {
	if [ "$2" -lt 4095 ]; then
		echo "$2"
	elif [ "$2" -eq 4096 ]; then
		echo -e "4096\t(Copy from the inner VID of received frame)"
	elif [ "$2" -eq 4097 ]; then
		echo -e "4097\t(Copy from the outer VID of received frame)"
	else
		echo -e "$2\t(Reserved)"
	fi
}

vlan_parse() {
	filter_outer_priority=$((($1 & 0xf0000000) >> 28))
	filter_outer_vid=$((($1 & 0x0fff8000) >> 15))
	filter_outer_tpid_dei=$((($1 & 0x00007000) >> 12))

	filter_inner_priority=$((($2 & 0xf0000000) >> 28))
	filter_inner_vid=$((($2 & 0x0fff8000) >> 15))
	filter_inner_tpid_dei=$((($2 & 0x00007000) >> 12))
	filter_extended_criteria=$((($2 & 0x00000ff0) >> 4))
	filter_ethertype=$(($2 & 0x0000000f))

	treatment_remove_tags=$((($3 & 0xc0000000) >> 30))
	treatment_outer_priority=$((($3 & 0x000f0000) >> 16))
	treatment_outer_vid=$((($3 & 0x0000fff8) >> 3))
	treatment_outer_tpid_dei=$(($3 & 0x00000007))

	treatment_inner_priority=$((($4 & 0x000f0000) >> 16))
	treatment_inner_vid=$((($4 & 0x0000fff8) >> 3))
	treatment_inner_tpid_dei=$(($4 & 0x00000007))

	if $TABLE; then
		echo -ne "${filter_outer_priority}\t${filter_outer_vid}\t${filter_outer_tpid_dei}\t"
		echo -ne "${filter_inner_priority}\t${filter_inner_vid}\t${filter_inner_tpid_dei}\t${filter_ethertype}\t${filter_extended_criteria}\t"
		echo -ne "${treatment_remove_tags}\t${treatment_outer_priority}\t${treatment_outer_vid}\t${treatment_outer_tpid_dei}\t"
		echo -ne "${treatment_inner_priority}\t${treatment_inner_vid}\t${treatment_inner_tpid_dei}"
		echo
	else
		echo -ne "Filter Outer Priority:\t\t"
		output_priority o $filter_outer_priority
		echo -ne "Filter Outer VID:\t\t"
		output_vid o $filter_outer_vid
		echo -e "Filter Outer TPID/DEI:\t\t$filter_outer_tpid_dei"

		echo -ne "Filter Inner Priority:\t\t"
		output_priority i $filter_inner_priority
		echo -ne "Filter Inner VID:\t\t"
		output_vid i $filter_inner_vid
		echo -e "Filter Inner TPID/DEI:\t\t$filter_inner_tpid_dei"

		echo -e "Filter EtherType:\t\t$filter_ethertype"
		echo -e "Filter Extended Criteria:\t$filter_extended_criteria"

		echo -e "Treatment tags to remove:\t$treatment_remove_tags"
		echo -ne "Treatment outer priority:\t"
		output_treat_priority o $treatment_outer_priority
		echo -ne "Treatment outer VID:\t\t"
		output_treat_vid o $treatment_outer_vid
		echo -e "Treatment outer TPID/DEI:\t$treatment_outer_tpid_dei"

		echo -ne "Treatment inner priority:\t"
		output_treat_priority i $treatment_inner_priority
		echo -ne "Treatment inner VID:\t\t"
		output_treat_vid i $treatment_inner_vid
		echo -e "Treatment inner TPID/DEI:\t$treatment_inner_tpid_dei"
	fi
}


ext_vlan_tables=$(omci_pipe.sh md | grep -E -o '^\|\s+171\s+\|\s+(\d+)\s+' | awk '{print $4}')

i=0
for ext_vlan_table in $ext_vlan_tables; do
	if $HEADER; then
		echo "Extended VLAN table $ext_vlan_table"
		echo "------------------------"
		if $TABLE; then
			echo -e "Filter Outer\t\tFilter Inner\t\tFilter Other\tTreatment Outer\t\t\tTreatment Inner"
			echo -e "Prio\tVID\tTPIDDEI\tPrio\tVID\tTPIDDEI\tEthTyp\tExtCrit\tTagRem\tPrio\tVID\tTPIDDEI\tPrio\tVID\tTPIDDEI"
		fi
	fi
	[ "$i" -gt 0 ] && echo

	data=$(omci_pipe.sh meg 171 $ext_vlan_table | grep -A999 '6 RX frame VLAN table' | grep -B999 "7 Associated ME ptr" | grep -E '^  ( 0x[0-9a-f]{2}){16}\s*$' | sed -r -e 's/\s+0x//g')
	for vlan_filter in $data; do
		w=$(echo $vlan_filter | sed -r 's/(.{8})/0x\1 /g')
		vlan_parse $w
		$TABLE || echo
	done
	i=$((i + 1))
done
