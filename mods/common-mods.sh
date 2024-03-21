#!/bin/bash
BANNER="$ROOT_DIR/etc/banner"
sed -E "s#(^\s+OpenWrt\s+.+$)#\1\n\n 8311 Community Firmware MOD [$FW_VARIANT] - $FW_VERSION ($FW_REVISION)\n https://github.com/djGrrr/8311-was-110-firmware-builder#g" -i "$BANNER"

UBIMGVARS="$ROOT_DIR/sbin/uboot_img_vars.sh"
echo "Patching '$UBIMGVARS'..."

UBIMGVARS_HEAD=$(grep -B99999999  -P '^_get_uboot_vars\(\)' "$UBIMGVARS")
UBIMGVARS_FOOT=$(grep -B3 -A99999999 -P '^get_uboot_vars\(\)' "$UBIMGVARS")

echo "$UBIMGVARS_HEAD" > "$UBIMGVARS"
cat >> "$UBIMGVARS" <<'UBIMGVARS_MOD'
	vars="active_bank img_validA:8311_sw_valA img_validB:8311_sw_valB img_versionA:8311_sw_verA img_versionB:8311_sw_verB commit_bank img_activate"

	printf "{"
	for var in $vars; do
		v=$(echo "$var" | cut -d: -f1)
		o=$(echo "$var" | cut -d: -f2)

		val=$([ -n "$o" ] && fw_printenv -n "$o" 2>/dev/null || fw_printenv -n "$v" 2>/dev/null)
		printf '"%s":"%s"' "$v" "$val"
		[ "$v" != "img_activate" ] && printf ","
	done
	printf "}\n"
UBIMGVARS_MOD
echo "$UBIMGVARS_FOOT" >> "$UBIMGVARS"


VEIP_MIB="$ROOT_DIR/etc/mibs/prx300_1V.ini"
echo "Patching '$VEIP_MIB'..."

VEIP_HEAD=$(grep -P -B99999999 '^# Virtual Ethernet Interface Point$' "$VEIP_MIB" | head -n -1)
VEIP_FOOT=$(grep -P -A99999999 '^# Virtual Ethernet Interface Point$' "$VEIP_MIB")

echo "$VEIP_HEAD" > "$VEIP_MIB"
# Enable LCT Management interface in VEIP mode
cat >> "$VEIP_MIB" <<'VEIP_LCT'

# PPTP Ethernet UNI
? 11 0x0101 0 0 0 0x00 1 1 0 2000 0 0xffff 0 0 0 0 0

VEIP_LCT
echo "$VEIP_FOOT" >> "$VEIP_MIB"


# Setup custom dropbear configuration links
rm -rfv "$ROOT_DIR/etc/dropbear"
ln -fsv "/ptconf/8311/.ssh" "$ROOT_DIR/root/.ssh"
ln -fsv "/ptconf/8311/dropbear" "$ROOT_DIR/etc/dropbear"

# Copy custom files
cp -va "files/common/." "$ROOT_DIR/"
cp -va "files/${FW_VARIANT}/." "$ROOT_DIR/"

sed -r 's#^(\s+)(.+ )(\|\| ubimkvol /dev/ubi0 -N rootfs_data)( .+$)#\1\# 8311 MOD: Always try to create rootfs_data at ID 6 first\n\1\2\3 -n 6\4 \3\4#g' -i "$ROOT_DIR/lib/preinit/06_create_rootfs_data"

# Remove dumb defaults for loid and lpwd
CONFIG_OMCI="$ROOT_DIR/etc/config/omci"
CONFIG_OMCI_FILTERED=$(grep -v -E '(loid|lpwd)' "$CONFIG_OMCI")
echo "$CONFIG_OMCI_FILTERED" > "$CONFIG_OMCI"

RC_LOCAL="$ROOT_DIR/etc/rc.local"

RC_LOCAL_HEAD=$(grep -P -B99999999 '^exit 0$' "$RC_LOCAL" | head -n -1)
RC_LOCAL_FOOT=$(grep -P -A99999999 '^exit 0$' "$RC_LOCAL")

DEFAULT_DELAY=15
[ "$FW_VARIANT" = "bfw" ] && DEFAULT_DELAY=30

echo "$RC_LOCAL_HEAD" > "$RC_LOCAL"
cat >> "$RC_LOCAL" <<FAILSAFE

# 8311 MOD: Failsafe, delay omcid start
DELAY=\$(fw_printenv -n 8311_failsafe_delay 2>/dev/null || echo "$DEFAULT_DELAY")
[ "\$DELAY" -ge 10 ] 2>/dev/null || DELAY=10
[ "\$DELAY" -le 300 ] || DELAY=300
sleep "\$DELAY" && [ ! -f /root/.failsafe ] && [ ! -f /tmp/.failsafe ] && [ ! -f /ptconf/.failsafe ] && /etc/init.d/omcid.sh start

FAILSAFE
echo "$RC_LOCAL_FOOT" >> "$RC_LOCAL"
chmod +x "$RC_LOCAL"


LIB_PON_SH="$ROOT_DIR/lib/pon.sh"
LIB_PON_SH_HEAD=$(grep -P -m 1 -B99999999 '^$' "$LIB_PON_SH")
LIB_PON_SH_TOP=$(grep -P -m 1 -A99999999 '^$' "$LIB_PON_SH" | grep -P -B99999999 '^pon_base_mac_get\(\)')
LIB_PON_SH_FOOT=$(grep -P -A99999999 '^\s+echo \$mac_addr$' "$LIB_PON_SH")

echo "$LIB_PON_SH_HEAD" > "$LIB_PON_SH"
cat >> "$LIB_PON_SH" <<'PONSHLIB'

_lib_8311 2>/dev/null || . /lib/8311.sh
PONSHLIB
echo "$LIB_PON_SH_TOP" >> "$LIB_PON_SH"
cat >> "$LIB_PON_SH" <<'PONSHMAC'
	# 8311 MOD: Use proper base MAC
	local mac_addr="$(get_8311_base_mac)"

PONSHMAC
echo "$LIB_PON_SH_FOOT" >> "$LIB_PON_SH"


cp -fv "libs/8311_${FW_VARIANT}.sh"  "$ROOT_DIR/lib/8311_backend.sh"
cp -fv "8311-xgspon-bypass/8311-detect-config.sh" "8311-xgspon-bypass/8311-fix-vlans.sh" "$ROOT_DIR/usr/sbin/"
ln -fsv "/usr/sbin/8311-detect-config.sh" "$ROOT_DIR/root/8311-detect-config.sh"
ln -fsv "/usr/sbin/8311-fix-vlans.sh" "$ROOT_DIR/root/8311-fix-vlans.sh"
mkdir -p "$ROOT_DIR/etc/crontabs"

touch "$ROOT_DIR/etc/crontabs/root"

sed -r 's#^(\s+)(start.+)$#\1\# 8311 MOD: Do not auto start omcid\n\1\# \2#g' -i "$ROOT_DIR/etc/init.d/omcid.sh"

CONFIG_OPTIC="$ROOT_DIR/etc/config/optic"
sed -r "s#(option 'tx_en_mode' ').*(')#\10\2#" -i "$CONFIG_OPTIC"
sed -r "s#(option 'tx_pup_mode' ').*(')#\11\2#" -i "$CONFIG_OPTIC"

OPTICDB_DEFAULT="$ROOT_DIR/etc/optic-db/default"
sed -r "s#(option 'tx_en_mode' ').*(')#\10\2#" -i "$OPTICDB_DEFAULT"
sed -r "s#(option 'tx_pup_mode' ').*(')#\11\2#" -i "$OPTICDB_DEFAULT"
sed "/option 'dg_dis'/d" -i "$OPTICDB_DEFAULT"

mkdir -pv "$ROOT_DIR/ptconf"

cat > "$ROOT_DIR/etc/8311_version" <<8311_VER
FW_VER=$FW_VER
FW_VERSION=$FW_VERSION
FW_LONG_VERSION=$FW_LONG_VERSION
FW_REV=$FW_REV
FW_REVISION=$FW_REVISION
FW_VARIANT=$FW_VARIANT
FW_SUFFIX=$FW_SUFFIX
8311_VER

# Change load order of mod_sfp_i2c module and add hack that sets the default virtual eeprom to the content of the physical one
rm -fv "$ROOT_DIR/etc/modules.d/20-pon-sfp-i2c"
ln -s "/sys/bus/platform/devices/18100000.ponmbox/eeprom50" "$ROOT_DIR/lib/firmware/sfp_eeprom0_hack.bin"
