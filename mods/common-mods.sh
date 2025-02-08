#!/bin/bash
BANNER="$ROOT_DIR/etc/banner"
sed -E "s#(^\s+OpenWrt\s+.+$)#\1\n\n 8311 Community Firmware MOD [$FW_VARIANT] - $FW_VERSION ($FW_REVISION)\n https://github.com/djGrrr/8311-was-110-firmware-builder#g" -i "$BANNER"

UBIMGVARS="$ROOT_DIR/sbin/uboot_img_vars.sh"
echo "Patching '$UBIMGVARS'..."

UBIMGVARS_HEAD=$(grep -B99999999  -P '^_get_uboot_vars\(\)' "$UBIMGVARS")
UBIMGVARS_FOOT=$(grep -B3 -A99999999 -P '^get_uboot_vars\(\)' "$UBIMGVARS")

echo "$UBIMGVARS_HEAD" > "$UBIMGVARS"
cat >> "$UBIMGVARS" <<'UBIMGVARS_MOD'
	vars="active_bank:8311_override_active img_validA:8311_sw_valA img_validB:8311_sw_valB img_versionA:8311_sw_verA img_versionB:8311_sw_verB commit_bank:8311_override_commit img_activate:8311_override_activate"

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

MIN_DELAY=0
DEFAULT_DELAY=15
[ "$FW_VARIANT" = "bfw" ] && DEFAULT_DELAY=30 && MIN_DELAY=10
# Failsafe下的处理
echo "$RC_LOCAL_HEAD" > "$RC_LOCAL"
cat >> "$RC_LOCAL" <<FAILSAFE

# 8311 MOD: Failsafe, delay omcid start
DELAY=\$(fw_printenv -n 8311_failsafe_delay 2>/dev/null || echo "$DEFAULT_DELAY")
[ "\$DELAY" -ge $MIN_DELAY ] 2>/dev/null || DELAY=$MIN_DELAY
[ "\$DELAY" -le "300" ] || DELAY=300
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


cp -fv "8311-xgspon-bypass/8311-detect-config.sh" "8311-xgspon-bypass/8311-fix-vlans.sh" "$ROOT_DIR/usr/sbin/"
cp -fv "8311-xgspon-bypass/8311-vlans-lib.sh" "$ROOT_DIR/lib/"
ln -fsv "/usr/sbin/8311-detect-config.sh" "$ROOT_DIR/root/8311-detect-config.sh"
ln -fsv "/usr/sbin/8311-fix-vlans.sh" "$ROOT_DIR/root/8311-fix-vlans.sh"
ln -fsv "/lib/8311-vlans-lib.sh" "$ROOT_DIR/root/8311-vlans-lib.sh"
mkdir -p "$ROOT_DIR/etc/crontabs"

touch "$ROOT_DIR/etc/crontabs/root"

sed -r 's#^(\s+)(start.+)$#\1\# 8311 MOD: Do not auto start omcid\n\1\# \2#g' -i "$ROOT_DIR/etc/init.d/omcid.sh"
sed -r 's/(stdout|stderr)=2/\1=1/g' -i "$ROOT_DIR/etc/init.d/omcid.sh"


CONFIG_OPTIC="$ROOT_DIR/etc/config/optic"
sed -r "s#(option 'tx_en_mode' ').*(')#\10\2#" -i "$CONFIG_OPTIC"
sed -r "s#(option 'tx_pup_mode' ').*(')#\11\2#" -i "$CONFIG_OPTIC"

OPTICDB_DEFAULT="$ROOT_DIR/etc/optic-db/default"
sed -r "s#(option 'tx_en_mode' ').*(')#\10\2#" -i "$OPTICDB_DEFAULT"
sed -r "s#(option 'tx_pup_mode' ').*(')#\11\2#" -i "$OPTICDB_DEFAULT"
sed "/option 'dg_dis'/d" -i "$OPTICDB_DEFAULT"

mkdir -pv "$ROOT_DIR/ptconf"

# Change load order of mod_sfp_i2c module and add hack that sets the default virtual eeprom to the content of the physical one
rm -fv "$ROOT_DIR/etc/modules.d/20-pon-sfp-i2c"
ln -s "/sys/bus/platform/devices/18100000.ponmbox/eeprom50" "$ROOT_DIR/lib/firmware/sfp_eeprom0_hack.bin"


if ls packages/common/busybox_*.ipk &>/dev/null; then
	echo "Removing all links to busybox..."
	find -L "$ROOT_DIR/" -samefile "$ROOT_DIR/bin/busybox" -exec rm -fv {} +
fi

if ls packages/common/*.ipk &>/dev/null; then
	for IPK in packages/common/*.ipk; do
		echo "Extracting '$(basename "$IPK")' to '$ROOT_DIR'."
		tar xfz "$IPK" -O -- "./data.tar.gz" | tar xvz -C "$ROOT_DIR/"
	done
fi

DROPBEAR="$ROOT_DIR/etc/init.d/dropbear"
# Fix dropbear init script from newer OpenWRT
sed -r 's/^extra_command "killclients" .+$/EXTRA_COMMANDS="killclients"\nEXTRA_HELP="    killclients Kill ${NAME} processes except servers and yourself"/' -i "$DROPBEAR"

# Setup custom dropbear configuration links
rm -rfv "$ROOT_DIR/etc/dropbear"
ln -fsv "/ptconf/8311/.ssh" "$ROOT_DIR/root/.ssh"
ln -fsv "/ptconf/8311/dropbear" "$ROOT_DIR/etc/dropbear"

ln -fsv "../init.d/sysntpd" "$ROOT_DIR/etc/rc.d/S98sysntpd"
