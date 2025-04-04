#!/bin/sh
_lib_8311_omci &>/dev/null || . /lib/8311-omci-lib.sh

HEADER=true
TABLE=false

_help() {
	printf -- '用于解码扩展VLAN表的工具\n\n'

	printf -- '用法 %s [选项]\n\n' "$0"

	printf -- '选项:\n'
	printf -- '-t --table\t输出表格格式而非用户友好格式\n'
	printf -- '-n --no-header\t不输出信息头\n'

	printf -- '-h --help\t显示帮助信息\n'

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
	[ "$1" = "i" ] && echo "内部" || echo "外部"
}

filter_priority() {
	local dir=$(dir "$1")

	if [ "$2" -le  7 ]; then
		echo "$2"
	elif [ "$2" -eq 8 ]; then
		echo -e "8\t(不根据${dir}优先级过滤)"
	elif [ "$2" -eq 14 ]; then
		if [ "$dir" = "内部" ]; then
			echo -e "14\t(无其他单标签规则时的默认过滤)"
		else
			echo -e "14\t(无其他双标签规则时的默认过滤)"
		fi
	elif [ "$2" -eq 15 ]; then
		if [ "$dir" = "内部" ]; then
			echo -e "15\t(无标签规则；忽略其他VLAN标签过滤字段)"
		else
			echo -e "15\t(非双标签规则；忽略外部标签过滤字段)"
		fi
	else
		echo -e "$2\t(保留)"
	fi
}

filter_vid() {
	local dir=$(dir "$1")

	if [ "$2" -lt 4095 ]; then
		echo "$2"
	elif [ "$2" -eq 4096 ]; then
		echo -e "4096\t(不根据${dir} VID过滤)";
	else
		echo -e "$2\t(保留)"；
	fi
}

filter_tpid_dei() {
	local dir=$(dir "$1")

	if [ "$2" -eq 0 ]; then
		echo -e "0\t(不根据${dir} TPID或DEI过滤)"
	elif [ "$2" -eq 4 ]; then
		echo -e "4\t(TPID = 0x8100，忽略DEI)"
	elif [ "$2" -eq 5 ]; then
		echo -e "5\t(TPID = 输入TPID，忽略DEI)"
	elif [ "$2" -eq 6 ]; then
		echo -e "6\t(TPID = 输入TPID，DEI = 0)"
	elif [ "$2" -eq 7 ]; then
		echo -e "7\t(TPID = 输入TPID，DEI = 1)"
	else
		echo -e "$2\t(保留)"
	fi
}

filter_ethertype() {
	if [ "$1" -eq 0 ]; then
		echo -e "0\t(不根据EtherType过滤)"
	elif [ "$1" -eq 1 ]; then
		echo -e "1\t(0x0800 - IPv4 IPoE)"
	elif [ "$1" -eq 2 ]; then
		echo -e "2\t(0x8863 / 0x8864 - PPPoE)"
	elif [ "$1" -eq 3 ]; then
		echo -e "3\t(0x0806 - ARP)"
	elif [ "$1" -eq 4 ]; then
		echo -e "4\t(0x86DD - IPv6 IPoE)"
	elif [ "$1" -eq 5 ]; then
		echo -e "5\t(0x888E - EAPOL)"
	else
		echo -e "$1\t(保留)"
	fi
}

filter_extended_criteria() {
	if [ "$1" -eq 0 ]; then
		echo -e "0\t(不根据扩展条件过滤)"
	elif [ "$1" -eq 1 ]; then
		echo -e "1\t(DHCPv4)"
	elif [ "$1" -eq 2 ]; then
		echo -e "2\t(DHCPv6)"
	else
		echo -e "$1\t(保留)"
	fi
}

treatment_remove_tags() {
	if [ "$1" -eq 3 ]; then
		echo -e "3\t(丢弃帧)"
	else
		echo "$1"
	fi
}

treatment_priority() {
	local dir=$(dir "$1")

	if [ "$2" -le  7 ]; then
		echo "$2"
	elif [ "$2" -eq 8 ]; then
		echo -e "8\t(从接收帧的内部优先级复制)"
	elif [ "$2" -eq 9 ]; then
		echo -e "9\t(从接收帧的外部优先级复制)"
	elif [ "$2" -eq 10 ]; then
		echo -e "10\t(根据DSCP到P-bit映射派生优先级)"
	elif [ "$2" -eq 15 ]; then
		echo -e "15\t(不添加${dir}标签)"
	else
		echo -e "$2\t(保留)"
	fi
}

treatment_vid() {
	if [ "$2" -lt 4095 ]; then
		echo "$2"
	elif [ "$2" -eq 4096 ]; then
		echo -e "4096\t(从接收帧的内部VID复制)"
	elif [ "$2" -eq 4097 ]; then
		echo -e "4097\t(从接收帧的外部VID复制)"
	else
		echo -e "$2\t(保留)"
	fi
}

treatment_tpid_dei() {
	if [ "$2" -eq 0 ]; then
		echo -e "0\t(TPID = 内部TPID, DEI = 内部DEI)"
	elif [ "$2" -eq 1 ]; then
		echo -e "1\t(TPID = 外部TPID, DEI = 外部DEI)"
	elif [ "$2" -eq 2 ]; then
		echo -e "2\t(TPID = 输出TPID, DEI = 内部DEI)"
	elif [ "$2" -eq 3 ]; then
		echo -e "3\t(TPID = 输出TPID, DEI = 外部DEI)"
	elif [ "$2" -eq 4 ]; then
		echo -e "4\t(TPID = 0x8100)"
	elif [ "$2" -eq 6 ]; then
		echo -e "6\t(TPID = 输出TPID, DEI = 0)"
	elif [ "$2" -eq 7 ]; then
		echo -e "7\t(TPID = 输出TPID, DEI = 1)"
	else
		echo -e "$2\t(保留)"
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
		echo -ne "过滤外部优先级：\t\t"
		filter_priority o $filter_outer_priority
		echo -ne "过滤外部VID：\t\t\t"
		filter_vid o $filter_outer_vid
		echo -ne "过滤外部TPID/DEI：\t\t"
		filter_tpid_dei o $filter_outer_tpid_dei

		echo -ne "过滤内部优先级：\t\t"
		filter_priority i $filter_inner_priority
		echo -ne "过滤内部VID：\t\t\t"
		filter_vid i $filter_inner_vid
		echo -ne "过滤内部TPID/DEI：\t\t"
		filter_tpid_dei i $filter_inner_tpid_dei

		echo -ne "过滤EtherType：\t\t\t"
		filter_ethertype $filter_ethertype
		echo -ne "过滤扩展条件：\t\t\t"
		filter_extended_criteria $filter_extended_criteria

		echo -ne "处理移除的标签：\t\t"
		treatment_remove_tags $treatment_remove_tags
		echo -ne "处理外部优先级：\t\t"
		treatment_priority o $treatment_outer_priority
		echo -ne "处理外部VID：\t\t\t"
		treatment_vid o $treatment_outer_vid
		echo -ne "处理外部TPID/DEI：\t\t"
		treatment_tpid_dei o $treatment_outer_tpid_dei

		echo -ne "处理内部优先级：\t\t"
		treatment_priority i $treatment_inner_priority
		echo -ne "处理内部VID：\t\t\t"
		treatment_vid i $treatment_inner_vid
		echo -ne "处理内部TPID/DEI：\t\t"
		treatment_tpid_dei i $treatment_inner_tpid_dei
	fi
}

ext_vlan_tables=$(mibs 171)
if [ -z "$ext_vlan_tables" ]; then
	echo "未检测到扩展VLAN表" >&2
	exit 1
fi

i=0
for ext_vlan_table in $ext_vlan_tables; do
	if $HEADER; then
		echo "扩展VLAN表 $ext_vlan_table"
		echo "------------------------"
		if $TABLE; then
			echo -e "过滤外部\t\t过滤内部\t\t其他过滤\t处理外部\t\t\t处理内部"
			echo -e "优先级\tVID\tTPIDDEI\t优先级\tVID\tTPIDDEI\tEth类型\t扩展条件\t标签移除\t优先级\tVID\tTPIDDEI\t优先级\tVID\tTPIDDEI"
		fi
	fi
	[ "$i" -gt 0 ] && echo

	data=$(mibattrdata 171 $ext_vlan_table 6)
	for vlan_filter in $data; do
		w=$(echo $vlan_filter | sed -r 's/(.{8})/0x\1 /g')
		vlan_parse $w
		$TABLE || echo
	done
	i=$((i + 1))
done
