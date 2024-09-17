#!/bin/bash
if { [ "$1" -lt 0 ] || [ "$1" -ge 0 ]; } 2>/dev/null; then
	TIMESTAMP="$1"
else
	TIMESTAMP=$(date '+%s')
fi
TIMESTAMP=$(($TIMESTAMP & 0xffffffff))

cat_data() {
	local max=false
	local size=
	local file=
	while [ $# -gt 0 ]; do
		case "$1" in
			-m)
				max=true
			;;
			*)
				if [ -z "$size" ]; then
					size="$((${1}))"
				elif [ -z "$file" ]; then
					file="${1}"
				fi
			;;
		esac
		shift
	done
	file="${file:-/dev/null}"

	{ cat "$file" ; $max || { cat /dev/zero | LC_ALL=C tr "\000" "\377"; }; } | head -c "$size"
}

rm -f whole_image/system_sw.img
ubinize -o whole_image/system_sw.img -p 128KiB -m 2048 -s 2048 -v system_sw.ini -Q "$TIMESTAMP"
echo

OUTIMG="out/whole-image.img"
echo -n "Building '$OUTIMG'..."

cat_data	0x00100000 "whole_image/uboot-azores-1.0.24.bin"	> "$OUTIMG"		# uboot
cat_data	0x00040000 "whole_image/ubootenv-azores.img"		>> "$OUTIMG"	# ubootconfigA
cat_data	0x00040000 "whole_image/ubootenv-azores.img"		>> "$OUTIMG"	# ubootconfigB
cat_data	0x00040000											>> "$OUTIMG"	# gphyfirmware
cat_data	0x00100000											>> "$OUTIMG"	# calibration
cat_data 	0x01000000											>> "$OUTIMG"	# bootcore
cat_data -m	0x06600000 "whole_image/system_sw.img"				>> "$OUTIMG" 	# system_sw
#cat_data	0x00600000											>> "$OUTIMG"	# ptdata
#cat_data	0x00140000 "whole_image/res.bin"					>> "$OUTIMG"    # res

echo " done"

FLSIMG="out/whole-image-endian.img"

echo -n "Creating endian reversed flash image '$FLSIMG'..."
tools/endianess_swap.sh "$OUTIMG" "$FLSIMG"
echo " done"

touch -d "@$TIMESTAMP" "$OUTIMG" "$FLSIMG"

#OUTIMG="out/whole-8311.img"
#echo -n "Building '$OUTIMG'..."

#cat_data	0x00100000 "whole_image/uboot-8311.bin"				> "$OUTIMG"		# uboot
#cat_data	0x00040000 "whole_image/ubootenv-8311.img"			>> "$OUTIMG"	# ubootconfigA
#cat_data	0x00040000 "whole_image/ubootenv-8311.img"			>> "$OUTIMG"	# ubootconfigB
#cat_data	0x00040000											>> "$OUTIMG"	# gphyfirmware
#cat_data	0x00100000											>> "$OUTIMG"	# calibration
#cat_data	0x01000000											>> "$OUTIMG"	# bootcore
#cat_data -m	0x06C00000 "whole_image/system_sw.img"				>> "$OUTIMG"	# system_sw
#cat_data	0x00140000 "whole_image/res.bin"					>> "$OUTIMG"	# res

#touch -d "@$TIMESTAMP" "$OUTIMG"
#echo " done"
