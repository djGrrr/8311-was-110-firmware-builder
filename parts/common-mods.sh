#!/bin/bash
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

# Copy custom Bell MIB
BELL_MIB="$ROOT_DIR/etc/mibs/prx300_1V_bell.ini"
cp -fv "files/prx300_1V_bell.ini" "$BELL_MIB"
