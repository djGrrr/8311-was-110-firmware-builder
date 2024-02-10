#!/bin/bash
OMCID="$ROOT_DIR/opt/intel/bin/omcid"
if check_file "$OMCID" "0aa64358a3afaa17b4edfed0077141981bc13322c7d1cf730abc251fae1ecbb1"; then
	echo "Patching '$OMCID'..."

	# omcid mod by up-n-atom to fix management with VEIP mode
	printf '\x00' | dd of="$OMCID" conv=notrunc seek=$((0x7F5C5)) bs=1 count=1 2>/dev/null

	# omcid mod by djGrrr to make default LOID and LPWD empty
	printf '\x00\x00\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0xF42F4)) bs=1 count=6 2>/dev/null
	printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0xF4304)) bs=1 count=9 2>/dev/null

	# patch uni2port to always set the port to 0 (by djGrrr)
#	printf '\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0x26008)) bs=1 count=4 2>/dev/null
#	printf '\x00' | dd of="$OMCID" conv=notrunc seek=$((0x2600d)) bs=1 count=1 2>/dev/null

	expected_hash "$OMCID" "62925b4dd5ca2b097f914aa4fb26247e72c04f18e7c8a9e0263d31c9817ea1fc"
#	expected_hash "$OMCID" "da19ae642b5f47b1b58a2e0f6535324f1be24069ce7e8868ba91e2a63b90b982"
fi

OMCID="$ROOT_DIR/usr/bin/omcid"
# Potrontec 1.18.1 OMCId v8.15.17
if check_file "$OMCID" "82b6746d5385d676765d185a21443fabcab63f193fac7eb56a1a8cd878f029d5"; then
	echo "Patching '$OMCID'..."

	# omcid mod by djGrrr to make default LOID and LPWD empty
	printf '\x00\x00\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0x9FBF8)) bs=1 count=6 2>/dev/null
	printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0x9FC08)) bs=1 count=9 2>/dev/null

	expected_hash "$OMCID" "184aad016a0d38da5c3a6fc8451f8b4971be59702d6d10a2bca379b2f9bce7f7"
fi

# libponnet mod for 1.0.12 to fix management with VEIP mode
LIBPONNET="$ROOT_DIR/usr/lib/libponnet.so.0.0.0"
if check_file "$LIBPONNET" "8075079231811f58dd4cec06ed84ff5d46a06e40b94c14263a56110edfa2a705"; then
	echo "Patching '$LIBPONNET'..."

	# patch pon_net_dev_db_add to return 0 instead of -1 when an existing device entry exists
	printf '\x00\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x51B9A)) bs=1 count=2 2>/dev/null

	# patch file location for IP Host hostname
	printf '/tmp/8311-iphost-hostname\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x92064)) bs=1 count=26 2>/dev/null

	# patch file location for IP Host domain
	printf '/tmp/8311-iphost-domainname\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x92090)) bs=1 count=28 2>/dev/null

	expected_hash "$LIBPONNET" "1d92a9cf288f64317f6d82e8f87651fbc07bef53ce3f4f28e73fc17e6041b107"
fi

# Potrontec 1.18.1 OMCId v8.15.17
if check_file "$LIBPONNET" "05536d164e51c5d412421a347a5c99b6883a53c57c24ed4d00f4b98b79cddfc3"; then
	echo "Patching '$LIBPONNET'..."

	# patch pon_net_dev_db_add to return 0 instead of -1 when an existing device entry exists, fixes VEIP management
	printf '\x00\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x3CDC2)) bs=1 count=2 2>/dev/null

	# patch file location for IP Host hostname
	printf '/tmp/8311-iphost-hostname\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x6BC40)) bs=1 count=26 2>/dev/null

	# patch file location for IP Host domain
	printf '/tmp/8311-iphost-domainname\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x6BC0C)) bs=1 count=28 2>/dev/null

	expected_hash "$LIBPONNET" "71e5fa85bde3793cdc1085781e3a1440fc9ef0bb8900c74d144b99be720ba50e"
fi

LIBPONHWAL="$ROOT_DIR/ptrom/lib/libponhwal.so"
if check_file "$LIBPONHWAL" "f0e48ceba56c7d588b8bcd206c7a3a66c5c926fd1d69e6d9d5354bf1d34fdaf6"; then
	echo "Patching '$LIBPONHWAL'..."

	# patch ponhw_get_hardware_ver to use the correct string length (by rajkosto)
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x278CB)) bs=1 count=1 2>/dev/null

	# patch ponhw_get_software_ver to use the correct string length (by rajkosto)
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x277C7)) bs=1 count=1 2>/dev/null
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x27823)) bs=1 count=1 2>/dev/null

	# patch ponhw_get_equipment_id to use the correct string length (by djGrrr)
	printf '\x14' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x27647)) bs=1 count=1 2>/dev/null

	expected_hash "$LIBPONHWAL" "624aa5875a7bcf4d91a060e076475336622b267ff14b9c8fbb87df30fc889788"
fi

# libponhwal mods for 1.0.8 to fix Software/Hardware versions and Equipment ID
if check_file "$LIBPONHWAL" "6af1b3b1fba25488fd68e5e2e2c41ab0e178bd190f0ba2617fc32bdfad21e4c4"; then
	echo "Patching '$LIBPONHWAL'..."

	# patch ponhw_get_hardware_ver to use the correct string length ((by djGrrr, based on rajkosto's patch for 1.0.12)
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x2738B)) bs=1 count=1 2>/dev/null

	# patch ponhw_get_software_ver to use the correct string length (by djGrrr, based on rajkosto's patch for 1.0.12)
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x27287)) bs=1 count=1 2>/dev/null
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x272E3)) bs=1 count=1 2>/dev/null

	# patch ponhw_get_equipment_id to use the correct string length (by djGrrr)
	printf '\x14' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x27107)) bs=1 count=1 2>/dev/null

	expected_hash "$LIBPONHWAL" "36b20ed9c64de010e14543659302fdb85090efc49e48c193c2c156f6333afaac"
fi
