#!/bin/bash

# Add MOD Version to webui
STATE_OVCT="$ROOT_DIR/www/html/stateOverview_ct.html"
dos2unix "$STATE_OVCT"

STATE_OVCT_HEAD=$(grep -B99999999 -A1 -P '<td id="SoftwareVersion"></td>' "$STATE_OVCT")
STATE_OVCT_FOOT=$(grep -A99999999 -P '<td id="SoftwareVersion"></td>' "$STATE_OVCT" | tail -n +3)

echo "$STATE_OVCT_HEAD" > "$STATE_OVCT"
cat >> "$STATE_OVCT" <<MOD_VERSION
					<tr>
						<td class="table_title" i18n="8311modver"></td>
						<td>[$FW_VARIANT] - $FW_VERSION ($FW_REVISION)</td>
					</tr>
MOD_VERSION
echo "$STATE_OVCT_FOOT" >> "$STATE_OVCT"
unix2dos "$STATE_OVCT"

# Modify language files
LANG_EN_GB="$ROOT_DIR/www/language/i18n_en_gb"
dos2unix "$LANG_EN_GB"

LANG_EN_GB_HEAD=$(grep -B99999999 -P '^\s+"softwarever":' "$LANG_EN_GB")
LANG_EN_GB_FOOT=$(grep -A99999999 -P '^\s+"softwarever":' "$LANG_EN_GB" | tail -n +2)

echo "$LANG_EN_GB_HEAD" > "$LANG_EN_GB"
cat >> "$LANG_EN_GB" <<MOD_LANG_EN
	"8311modver":"8311 Community MOD Version",
MOD_LANG_EN
echo "$LANG_EN_GB_FOOT" >> "$LANG_EN_GB"

sed -r 's/("regidtextlength":".+ octets)[^"]+"/\1"/g' -i "$LANG_EN_GB"
unix2dos "$LANG_EN_GB"

LANG_ZH_CN="$ROOT_DIR/www/language/i18n_zh_cn"
dos2unix "$LANG_ZH_CN"

LANG_ZH_CN_HEAD=$(grep -B99999999 -P '^\s+"softwarever":' "$LANG_ZH_CN")
LANG_ZH_CN_FOOT=$(grep -A99999999 -P '^\s+"softwarever":' "$LANG_ZH_CN" | tail -n +2)

echo "$LANG_ZH_CN_HEAD" > "$LANG_ZH_CN"
cat >> "$LANG_ZH_CN" <<MOD_LANG_CN
	"8311modver":"8311社区修改版",
MOD_LANG_CN
echo "$LANG_ZH_CN_FOOT" >> "$LANG_ZH_CN"

sed -r 's/("regidtextlength":".+位)[^"]+"/\1"/g' -i "$LANG_ZH_CN"
unix2dos "$LANG_ZH_CN"

OLTAUTH_JS="$ROOT_DIR/www/js/oltauth_comn.js"
OLTAUTH_JS_PART1=$(grep -B99999999 'Regid_text.length > 36' "$OLTAUTH_JS" | head -n -1)
OLTAUTH_JS_PART2=$(grep -A99999999 'Regid_text.length > 36' "$OLTAUTH_JS" | tail -n +2 | grep -B99999999 -A1 'function validCheck()')
OLTAUTH_JS_PART3=$(grep -A99999999 'function validCheck()' "$OLTAUTH_JS" | grep -A99999999 'if ( isCnInclude($("#Regid_text").val()) )' | grep -B99999999 -A1 'function validCheckCu()')
OLTAUTH_JS_PART4=$(grep -A99999999 'function validCheckCu()' "$OLTAUTH_JS" | grep -A99999999 'if ( isCnInclude($("#Regid_text").val()) )')

echo "$OLTAUTH_JS_PART1" > "$OLTAUTH_JS"
cat >> "$OLTAUTH_JS" <<REG_ID_CHECK
			if( Regid_text.length > 36 ) {
REG_ID_CHECK
echo "$OLTAUTH_JS_PART2" >> "$OLTAUTH_JS"
echo "$OLTAUTH_JS_PART3" >> "$OLTAUTH_JS"
echo "$OLTAUTH_JS_PART4" >> "$OLTAUTH_JS"

MAIN_HTML="$ROOT_DIR/www/html/main.html"
MAIN_HTML_HEAD=$(grep -B99999999 -P '<img[^"]+"[^"]*logo[^"]*"' "$MAIN_HTML" | head -n -1)
MAIN_HTML_FOOT=$(grep -A99999999 -P '<img[^"]+"[^"]*logo[^"]*"' "$MAIN_HTML" | tail -n +2)

echo "$MAIN_HTML_HEAD" > "$MAIN_HTML"
cat >> "$MAIN_HTML" <<8311_LOGO
					<img src="../image/logo_8311.png" id="8311logo" style="width: 73px; height: 40px; margin-left: 10px; margin-top: 13px;">
					<img src="../image/logo_azores.png" id="logoimg" style="width: 126px; height: 40px; margin-left: 30px; margin-top: 13px;">
8311_LOGO
echo "$MAIN_HTML_FOOT" >> "$MAIN_HTML"

# Fix Registration ID default value of "NULL"
sed -r 's#(<param name="RegistrationID" .+ value=)"\S+"(></param>)#\1""\2#g' -i "$ROOT_DIR/ptrom/ptconf/param_ct.xml"


BFW_START="$ROOT_DIR/etc/init.d/bfw_start.sh"

# Push messages about changes to UART to the console
sed -r 's#^(\s*echo \".+\!\!\")$#\1 | to_console#g' -i "$BFW_START"

BFW_HEAD=$(grep -P -B99999999 '^#read bootcmd, if not default, modify$' "$BFW_START" | head -n -2)
BFW_HEAD2=$(grep -P -A99999999 '^./ptrom/bin/set_bootcmd_env$' "$BFW_START" | tail -n +2 | grep -P -B99999999 '^#set FXM_TXFAULT_EN$' | head -n -1)
BFW_FOOT=$(grep -P -A99999999 '^pon 1pps_event_enable$' "$BFW_START")

echo "$BFW_HEAD" > "$BFW_START"
echo >> "$BFW_START"
echo "$BFW_HEAD2" >> "$BFW_START"
echo >> "$BFW_START"
cat >> "$BFW_START" <<'BFW_START_MODS'

_lib_8311 2>/dev/null || . /lib/8311.sh

# Remove Reservedata as it causes the stick to reboot every few minutes
uci -qc /ptdata delete factory_conf.Reservedata

# 8311 MOD: Disable factory mode unless specifically enabled
FAC_MODE=$(fwenv_get_8311 factory_mode)
[ "$FAC_MODE" = "1" ] || FAC_MODE=0

FAC_MODE_FLAG="/ptdata/factorymodeflag"
[ -e "$FAC_MODE_FLAG" ] && CUR_FAC_MODE=1 || CUR_FAC_MODE=0

FAC_CHANGES="$(uci -qc /ptdata changes factory_conf)"
if [ -n "$FAC_CHANGES" ] || [ "$CUR_FAC_MODE" != "$FAC_MODE" ]; then
	mount -o remount,rw /ptdata

	[ -n "$FAC_CHANGES" ] && uci -qc /ptdata commit factory_conf

	if [ "$FAC_MODE" -eq 1 ]; then
		touch "$FAC_MODE_FLAG"
	else
		rm -f "$FAC_MODE_FLAG"
		mount -o remount,ro /ptdata
	fi
fi

BFW_START_MODS

echo "$BFW_FOOT" >> "$BFW_START"

if [ "$KERNEL_VARIANT" = "basic" ]; then
	rm -rfv "$ROOT_DIR/lib/modules" #"$ROOT_DIR/lib/firmware"
	cp -va "$ROOT_BASIC/lib/modules/." "$ROOT_DIR/lib/modules"
	cp -va "$ROOT_BASIC/lib/firmware/." "$ROOT_DIR/lib/firmware"
fi
