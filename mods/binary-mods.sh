#!/bin/bash
OMCID="$ROOT_DIR/opt/intel/bin/omcid"
# Azores 1.0.12
if check_file "$OMCID" "0aa64358a3afaa17b4edfed0077141981bc13322c7d1cf730abc251fae1ecbb1"; then
	echo "Patching '$OMCID'..."

	# omcid mod by djGrrr to make default LOID and LPWD empty
	printf '\x00\x00\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0xF42F4)) bs=1 count=6 2>/dev/null
	printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0xF4304)) bs=1 count=9 2>/dev/null

	expected_hash "$OMCID" "cb4c3e631ea783aebf8603298da0b7a2ac0c3750a2d35be0c5f80a93e64228ec"
fi

# Azores 1.0.19
if check_file "$OMCID" "d696843c3801cb68f9d779ed95bd72299fcb2fa05459c17bac5d346645562067"; then
	echo "Patching '$OMCID'..."

	# omcid mod by djGrrr to make default LOID and LPWD empty
	printf '\x00\x00\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0xF43F4)) bs=1 count=6 2>/dev/null
	printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0xF4404)) bs=1 count=9 2>/dev/null

	expected_hash "$OMCID" "0111a39c55f776e9b9756833943a06a19bffe973e601e8a1abb1dfab3647f733"
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

# PTXG_CX_V0.03
if check_file "$OMCID" "5217dccf98cf8c75bc1b8ba380a92514511a77c40803a9718651b1f2bb5a9a5a"; then
	echo "Patching '$OMCID'..."

	# omcid mod by djGrrr to make default LOID and LPWD empty
	printf '\x00\x00\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0xA04C8)) bs=1 count=6 2>/dev/null
	printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0xA04D8)) bs=1 count=9 2>/dev/null

	# omci_sip_user_data.c - ME 153 function sip_user_update_timeout_handler - fix data length when reading ME 148 attribute username2
	printf '\x19' | dd of="$OMCID" conv=notrunc seek=$((0x80C77)) bs=1 count=1 2>/dev/null

	# omci_sip_agent_config_data.c - ME 150 function me_update - fix data lengths when reading ME 136 and 134 attributes
	printf '\x02' | dd of="$OMCID" conv=notrunc seek=$((0x82403)) bs=1 count=1 2>/dev/null
	printf '\x3C' | dd of="$OMCID" conv=notrunc seek=$((0x825C7)) bs=1 count=1 2>/dev/null
	printf '\x04' | dd of="$OMCID" conv=notrunc seek=$((0x825CB)) bs=1 count=1 2>/dev/null
	printf '\x16' | dd of="$OMCID" conv=notrunc seek=$((0x825F1)) bs=1 count=1 2>/dev/null
	printf '\xB6' | dd of="$OMCID" conv=notrunc seek=$((0x825F5)) bs=1 count=1 2>/dev/null
	printf '\xAF\xB6\x00\x10\x24\x16\x00\x04' | dd of="$OMCID" conv=notrunc seek=$((0x82624)) bs=1 count=8 2>/dev/null
	printf '\x6C' | dd of="$OMCID" conv=notrunc seek=$((0x8262F)) bs=1 count=1 2>/dev/null
	printf '\x02' | dd of="$OMCID" conv=notrunc seek=$((0x82633)) bs=1 count=1 2>/dev/null

	expected_hash "$OMCID" "c1df5decc2aa80a583abf0d8b1a237cc603ceeabd4acee4f7e8bbb6a91fd6848"
fi

# Potrontec 1.18.1 OMCId v8.15.17 and PTXG_CX_V0.03
LIBPON="$ROOT_DIR/usr/lib/libpon.so.0.0.0"
if check_file "$LIBPON" "401cc97e0f43b6b08a1d27f7be94a9e37fa798a810ae89838776f14b55e66cc1"; then
	echo "Patching '$LIBPON'..."

	# NOP system() calls to sfp_i2c
	printf '\x00\x00\x00\x00' | dd of="$LIBPON" conv=notrunc seek=$((0x17850)) bs=1 count=4 2>/dev/null
	printf '\x00\x00\x00\x00' | dd of="$LIBPON" conv=notrunc seek=$((0x17894)) bs=1 count=4 2>/dev/null
	printf '\x00\x00\x00\x00' | dd of="$LIBPON" conv=notrunc seek=$((0x178BC)) bs=1 count=4 2>/dev/null
	printf '\x00\x00\x00\x00' | dd of="$LIBPON" conv=notrunc seek=$((0x17940)) bs=1 count=4 2>/dev/null
	printf '\x00\x00\x00\x00' | dd of="$LIBPON" conv=notrunc seek=$((0x179D8)) bs=1 count=4 2>/dev/null
	printf '\x00\x00\x00\x00' | dd of="$LIBPON" conv=notrunc seek=$((0x17A08)) bs=1 count=4 2>/dev/null

	expected_hash "$LIBPON" "b9deb9b22715a4c4f54307939d94ac7b15e116aa5f5edabea5ba7365d3b807dc"
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

# libponnet mod for 1.0.19 to fix management with VEIP mode
if check_file "$LIBPONNET" "f1031d3452f86647dbdf4b6c94abaccdc05b9d3b2c339bf560db0191e799f0c6"; then
	echo "Patching '$LIBPONNET'..."

	# patch pon_net_dev_db_add to return 0 instead of -1 when an existing device entry exists
	printf '\x00\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x51B9A)) bs=1 count=2 2>/dev/null

	# patch file location for IP Host hostnam
	printf '/tmp/8311-iphost-hostname\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x92084)) bs=1 count=26 2>/dev/null

	# patch file location for IP Host domain
	printf '/tmp/8311-iphost-domainname\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x920B0)) bs=1 count=28 2>/dev/null

	expected_hash "$LIBPONNET" "baa8d1dc984387aaec12afe8f24338b19b8b162430ebea11d670c924c09cad00"
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

# PTXG_CX_V0.03
if check_file "$LIBPONNET" "ac12631273e8cf069aecbba55e02ace987d54ddf70bc0e14211dabf4abc600b7"; then
	echo "Patching '$LIBPONNET'..."

	# patch pon_net_dev_db_add to return 0 instead of -1 when an existing device entry exists, fixes VEIP management
	printf '\x00\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x3D1D2)) bs=1 count=2 2>/dev/null

	# patch file location for IP Host hostname
	printf '/tmp/8311-iphost-hostname\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x6C050)) bs=1 count=26 2>/dev/null

	# patch file location for IP Host domain
	printf '/tmp/8311-iphost-domainname\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x6C01C)) bs=1 count=28 2>/dev/null

	expected_hash "$LIBPONNET" "687f88bda014c86e7c6bff59857d10ea3bfe7307d6204bc327c616e8b39b20bc"
fi

LIBPONHWAL="$ROOT_DIR/ptrom/lib/libponhwal.so"
# libponhwal mods for 1.0.12 to fix Software/Hardware versions and Equipment ID
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

# libponhwal mods for 1.0.19 to fix Software/Hardware versions and Equipment ID
if check_file "$LIBPONHWAL" "cd157969cd9127d97709a96f3612f6f7c8f0eff05d4586fde178e9c4b7a4d362"; then
	echo "Patching '$LIBPONHWAL'..."

	# patch ponhw_get_hardware_ver to use the correct string length (by djGrrr, based on rajkosto's patch for 1.0.12)
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x278A3)) bs=1 count=1 2>/dev/null

	# patch ponhw_get_software_ver to use the correct string length (by djGrrr, based on rajkosto's patch for 1.0.12)
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x2779F)) bs=1 count=1 2>/dev/null
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x277FB)) bs=1 count=1 2>/dev/null

	# patch ponhw_get_equipment_id to use the correct string length (by djGrrr)
	printf '\x14' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x2C2B7)) bs=1 count=1 2>/dev/null

	expected_hash "$LIBPONHWAL" "48f932b62fd22c693bae0aa99962a4821ef18f503eed3822d41d44330cb32db5"
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
