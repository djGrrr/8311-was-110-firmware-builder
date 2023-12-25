#!/bin/bash
_help() {
	printf -- 'Tool for building new modded WAS-110 firmware images\n\n'
	printf -- 'Usage: %s [options]\n\n' "$0"
	printf -- 'Options:\n'
	printf -- '-i --image <filename>\t\tSpecify stock local upgrade image file.\n'
	printf -- '-I --image-dir <dir>\t\tSpecify stock image directory (must contain bootcore.bin, kernel.bin, and rootfs.img).\n'
	printf -- '-o --image-out <filename>\tSpecify local upgrade image to output.\n'
	printf -- '-h --help\t\t\tThis help text\n'
}

IMGFILE=
IMGDIR=
OUT_DIR=$(realpath "out")
IMG_OUT="$OUT_DIR/local-upgrade.img"
LIB_DIR=$(realpath "lib")

while [ $# -gt 0 ]; do
	case "$1" in
		-i|--image)
			IMGFILE="$2"
			shift
		;;
		-I|--image-dir)
			IMGDIR="$2"
			shift
		;;
		-o|--image-out)
			IMG_OUT="$2"
			shift
		;;
		--help|-h)
			_help
			exit 0
		;;
		*)
			_help
			exit 1
		;;
	esac
	shift
done

_err() {
	echo "$1" >&2
	exit ${2:-1}
}

sha256() {
	sha256sum "$1" | awk '{print $1}'
}

check_file() {
	[ -f "$1" ] && [ "$(sha256 "$1")" = "$2" ]
}

expected_hash() {
	EXPECTED_HASH="$2"
	FINAL_HASH=$(sha256 "$1")
	if ! [ "$FINAL_HASH" = "$EXPECTED_HASH" ]; then
		_err "Final '$1' SHA256 hash '$FINAL_HASH' != '$EXPECTED_HASH'" >&2
	fi
}

GIT_HASH=$(git rev-parse --short HEAD)
GIT_DIFF=$(git diff HEAD)
GIT_TAG=$(git tag --points-at HEAD | grep -P '^v\d+\.\d+\.\d+' | sort -V -r | head -n1)

FW_PREFIX=""
[ -n "$GIT_DIFF" ] && FW_SUFFIX="~dev"
[ -n "$GIT_TAG" ] && FW_VERSION="$GIT_TAG$FW_SUFFIX" || FW_VERSION="dev"
FW_HASH="$GIT_HASH$FW_SUFFIX"


set -e

HEADER=
if [ -n "$IMGFILE" ]; then
	[ -f "$IMGFILE" ] || _err "Image file '$IMGFILE' does not exist."

	HEADER="$OUT_DIR/header.bin"
	BOOTCORE="$OUT_DIR/bootcore.bin"
	KERNEL="$OUT_DIR/kernel.bin"
	ORIG_ROOTFS="$OUT_DIR/rootfs-orig.img"
	rm -rfv "$OUT_DIR"
	mkdir -pv "$OUT_DIR"

	./extract.sh -i "$IMGFILE" -H "$HEADER" -b "$BOOTCORE" -k "$KERNEL" -r "$ORIG_ROOTFS" || _err "Error extracting image '$IMGFILE'"
elif [ -n "$IMGDIR" ] && [ -d "$IMGDIR" ]; then
	IMG_DIR=$(realpath "$IMGDIR")
	[ -d "$IMG_DIR" ] || _err "Image directory '$IMG_DIR' does not exist."

	HEADER="$IMG_DIR/header.bin"
	BOOTCORE="$IMG_DIR/bootcore.bin"
	KERNEL="$IMG_DIR/kernel.bin"
	ORIG_ROOTFS="$IMG_DIR/rootfs.img"

	rm -rfv "$OUT_DIR"
    mkdir -pv "$OUT_DIR"
else
	_err "Muat specify one of --image or --image-dir"
fi

echo

ROOTFS="$OUT_DIR/rootfs.img"

[ -f "$BOOTCORE" ] || _err "Bootcore file '$BOOTCORE' does not exist."
[ -f "$KERNEL" ] || _err "Kernel file '$KERNEL' does not exist."
[ -f "$ORIG_ROOTFS" ] || _err "RootFS file '$ORIG_ROOTFS' does not exist."

ROOT_DIR=$(realpath "rootfs")
rm -rfv "$ROOT_DIR"

sudo unsquashfs -d "$ROOT_DIR" "$ORIG_ROOTFS" || _err "Error unsquashifying RootFS image '$ORIG_ROOTFS'"

USER=$(id -un)
GROUP=$(id -gn)

sudo chown -R "$USER:$GROUP" "$ROOT_DIR"


BANNER="$ROOT_DIR/etc/banner"
sed -E "s#(^\s+OpenWrt\s+.+$)#\1\n\n 8311 Community Firmware MOD - $FW_VERSION ($FW_HASH)\n https://github.com/djGrrr/8311-was-110-firmware-builder#g" -i "$BANNER"

# Add MOD Version to webui
STATE_OVCT="$ROOT_DIR/www/html/stateOverview_ct.html"
dos2unix "$STATE_OVCT"

STATE_OVCT_HEAD=$(grep -B99999999 -A1 -P '<td id="SoftwareVersion"></td>' "$STATE_OVCT")
STATE_OVCT_FOOT=$(grep -A99999999 -P '<td id="SoftwareVersion"></td>' "$STATE_OVCT" | tail -n +3)

echo "$STATE_OVCT_HEAD" > "$STATE_OVCT"
cat >> "$STATE_OVCT" <<MOD_VERSION
		            <tr>
		                <td class="table_title" i18n="8311modver"></td>
		                <td>$FW_VERSION ($FW_HASH)</td>
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

# Add logo
cp -fv "files/logo_8311.png" "$ROOT_DIR/www/image/logo_8311.png"

MAIN_HTML="$ROOT_DIR/www/html/main.html"
MAIN_HTML_HEAD=$(grep -B99999999 '../image/logo_azores.png' "$MAIN_HTML" | head -n -1)
MAIN_HTML_FOOT=$(grep -A99999999 '../image/logo_azores.png' "$MAIN_HTML" | tail -n +2)

echo "$MAIN_HTML_HEAD" > "$MAIN_HTML"
cat >> "$MAIN_HTML" <<8311_LOGO
					<img src="../image/logo_8311.png" id="8311logo" style="width: 73px; height: 40px; margin-left: 10px; margin-top: 13px;">
					<img src="../image/logo_azores.png" id="logoimg" style="width: 126px; height: 40px; margin-left: 30px; margin-top: 13px;">
8311_LOGO
echo "$MAIN_HTML_FOOT" >> "$MAIN_HTML"

# Fix Registration ID default value of "NULL"
sed -r 's#(<param name="RegistrationID" .+ value=)"\S+"(></param>)#\1""\2#g' -i "$ROOT_DIR/ptrom/ptconf/param_ct.xml"

# Remove dumb defaults for loid and lpwd
CONFIG_OMCI="$ROOT_DIR/etc/config/omci"
CONFIG_OMCI_FILTERED=$(grep -v -E '(loid|lpwd)' "$CONFIG_OMCI")
echo "$CONFIG_OMCI_FILTERED" > "$CONFIG_OMCI"


BFW_START="$ROOT_DIR/etc/init.d/bfw_start.sh"


# Push messages about changes to UART to the console
sed -r 's#^(\s*echo \".+\!\!\")$#\1 | tee -a /dev/console#g' -i "$BFW_START"

BFW_HEAD=$(grep -P -B99999999 '^#read bootcmd, if not default, modify$' "$BFW_START" | head -n -2)
BFW_HEAD2=$(grep -P -A99999999 '^./ptrom/bin/set_bootcmd_env$' "$BFW_START" | tail -n +2 | grep -P -B99999999 '^#set FXM_TXFAULT_EN$' | head -n -1)
BFW_CONSOLE=$(grep -P -A99999999 '^#set FXM_TXFAULT_EN$' "$BFW_START" | grep -P -B99999999 '^#set DYING GASP EN$' | head -n -1)
BFW_CONSOLE_HEAD=$(echo "$BFW_CONSOLE" | grep -P -B99999999 '^/ptrom/bin/gpio_cmd set 30 0$')
BFW_CONSOLE_FOOT=$(echo "$BFW_CONSOLE" | grep -P -A99999999 '^/ptrom/bin/gpio_cmd set 30 0$' | tail -n +2)
BFW_DYING_GASP=$(grep -P -A99999999 '^#set DYING GASP EN$' "$BFW_START" | grep -P -B99999999 '^pon 1pps_event_enable$' | head -n -1)
BFW_FOOT=$(grep -P -A99999999 '^pon 1pps_event_enable$' "$BFW_START")

cp -fv "$LIB_DIR/hexbin.sh" "$ROOT_DIR/lib/functions/hexbin.sh"

echo "$BFW_HEAD" > "$BFW_START"
echo >> "$BFW_START"
echo "$BFW_HEAD2" >> "$BFW_START"
echo >> "$BFW_START"
cat >> "$BFW_START" <<'BFW_START_MODS'


. /lib/functions/hexbin.sh

# 8311 MOD: fwenvsfor GPON Serial Number and Vendor ID
GPON_SN=$(fw_printenv -n 8311_gpon_sn 2>/dev/null)
VENDOR_ID=$(fw_printenv -n 8311_vendor_id 2>/dev/null)
if [ -n "$GPON_SN" ]; then
	echo "Setting PON SN: $GPON_SN" | tee -a /dev/console
	VENDOR_ID="${VENDOR_ID:-$(echo "$GPON_SN" | head -c 4)}"
	uci -qc /ptdata set factory_conf.GponSN=key
	uci -qc /ptdata set factory_conf.GponSN.encryflag=0
	uci -qc /ptdata set factory_conf.GponSN.value="$GPON_SN"
fi

if [ -n "$VENDOR_ID" ]; then
	echo "Setting PON Vendor ID: $VENDOR_ID" | tee -a /dev/console
	uci -qc /ptdata set factory_conf.VendorCode=key
	uci -qc /ptdata set factory_conf.VendorCode.encryflag=0
	uci -qc /ptdata set factory_conf.VendorCode.value="$VENDOR_ID"
fi

# 8311 MOD: fwenv to set Device SN
DEVICE_SN=$(fw_printenv -n 8311_device_sn 2>/dev/null)
if [ -n "$DEVICE_SN" ]; then
	# this only really changes what's in load_cli and the webui, so no need to echo to console
	uci -qc /ptdata set factory_conf.SerialNumber=key
	uci -qc /ptdata set factory_conf.SerialNumber.encryflag=0
	uci -qc /ptdata set factory_conf.SerialNumber.value="$DEVICE_SN"
fi

# 8311 MOD: fwenv to set Registration ID
REG_ID_HEX=$({ fw_printenv -n 8311_reg_id_hex 2>/dev/null | filterhex; } || echo -n "$(fw_printenv -n 8311_reg_id 2>/dev/null)" | str2hex)
if [ -n "$REG_ID_HEX" ]; then
	REG_ID_PRINTABLE=$(echo -n "$REG_ID_HEX" | hex2printable)
	echo "Setting PON registration ID to: $(echo $(echo "$REG_ID_HEX" | awk '{gsub(/.{2}/,"0x& ")}1')) ($REG_ID_PRINTABLE)" | tee -a /dev/console

	uci -qc /ptdata set factory_conf.GPONPassWord=key
	uci -qc /ptdata set factory_conf.GPONPassWord.encryflag=1
	uci -qc /ptdata set factory_conf.GPONPassWord.value="$(echo -n "$REG_ID_HEX" | sed 's/\([0-9A-F]\{2\}\)/\\\\\\x\1/gI' | xargs printf | base64)"

	uci -qc /ptconf delete usrconfig_conf.InternetGatewayDevice__DeviceInfo__.RegistrationID
	[ -n "$(uci -qc /ptconf changes usrconfig_conf)" ] && uci -qc /ptconf commit usrconfig_conf
fi

# 8311 MOD: fwenvs to set software versions (omci_pipe.sh meg 7 0/1)
SW_VERSION_A=$({ fw_printenv -n 8311_sw_verA || fw_printenv -n 8311_sw_ver || fw_printenv -n 8311_sw_verB; } 2>/dev/null | head -c 14)
if [ -n "$SW_VERSION_A" ]; then
	echo "Setting PON image A version: $SW_VERSION_A" | tee -a /dev/console
	uci -qc /ptconf set sysinfo_conf.SoftwareVersion_A=key
	uci -qc /ptconf set sysinfo_conf.SoftwareVersion_A.encryflag=0
	uci -qc /ptconf set sysinfo_conf.SoftwareVersion_A.value="$SW_VERSION_A"
fi

SW_VERSION_B=$({ fw_printenv -n 8311_sw_verB || fw_printenv -n 8311_sw_ver || fw_printenv -n 8311_sw_verA; } 2>/dev/null | head -c 14)
if [ -n "$SW_VERSION_B" ]; then
	echo "Setting PON image B version: $SW_VERSION_B" | tee -a /dev/console
	uci -qc /ptconf set sysinfo_conf.SoftwareVersion_B=key
	uci -qc /ptconf set sysinfo_conf.SoftwareVersion_B.encryflag=0
	uci -qc /ptconf set sysinfo_conf.SoftwareVersion_B.value="$SW_VERSION_B"
fi

# 8311 MOD: fwenv to set hardware version (omci_pipe.sh meg 256 0)
HW_VERSION=$(fw_printenv -n 8311_hw_ver 2>/dev/null | head -c 14)
if [ -n "$HW_VERSION" ]; then
	# this only really changes what's in load_cli and the webui, so no need to echo to console
	uci -qc /ptdata set factory_conf.HardwareVersion=key
	uci -qc /ptdata set factory_conf.HardwareVersion.encryflag=0
	uci -qc /ptdata set factory_conf.HardwareVersion.value="$HW_VERSION"
fi


[ -n "$(uci -qc /ptconf changes sysinfo_conf)" ] && uci -qc /ptconf commit sysinfo_conf

if [ -n "$(uci -qc /ptdata changes factory_conf)" ]; then
	mount -o remount,rw /ptdata
	uci -qc /ptdata commit factory_conf
	[ -e "/ptdata/factorymodeflag" ] || mount -o remount,ro /ptdata
fi


BFW_START_MODS

echo "$BFW_DYING_GASP" >> "$BFW_START"
echo >> "$BFW_START"
echo "$BFW_CONSOLE_HEAD" >> "$BFW_START"
cat >> "$BFW_START" <<'CONSOLE_FWENV'

# 8311 MOD: fwenv for enabling UART
console_en=$(fw_printenv -n 8311_console_en 2>/dev/null)
if [ "$console_en" = "1" ]; then
    echo "fwenv console_en set console enable!!" | tee -a /dev/console
    /ptrom/bin/gpio_cmd set 30 1
fi
CONSOLE_FWENV
echo "$BFW_CONSOLE_FOOT" >> "$BFW_START"

# Don't set console GPIO til the setting is determined
sed -r 's#/ptrom/bin/gpio_cmd set 30 (0|1)$#CONSOLE_EN=\1#g' -i "$BFW_START"

cat >> "$BFW_START" <<'CONSOLE_SET'

# 8311 MOD: Enable or Disable UART TX
if [ "$CONSOLE_EN" = "1" ]; then
    /ptrom/bin/gpio_cmd set 30 1
else
	/ptrom/bin/gpio_cmd set 30 0
fi
CONSOLE_SET
echo >> "$BFW_START"
echo "$BFW_FOOT" >> "$BFW_START"
cat >> "$BFW_START" <<'EQUIPMENTID_MOD'

# 8311 MOD: fwenv for Equipment ID
(
	while [ ! -f "/tmp/deviceinfo" ]; do
		sleep 1
	done

	EQUIPMENT_ID=$(fw_printenv -n 8311_equipment_id 2>/dev/null | head -c 20)
	if [ -n "$EQUIPMENT_ID" ]; then
		echo "Setting PON Equipment ID: $EQUIPMENT_ID" | tee -a /dev/console
		uci -qc /tmp set deviceinfo.devicetype.value="$EQUIPMENT_ID"
		uci -qc /tmp commit deviceinfo
	fi
) &

EQUIPMENTID_MOD

cat >> "$BFW_START" <<'RX_LOS'

# 8311 MOD: start rx_los script
/usr/sbin/8311-rx_los.sh &

# 8311 MOD: start vlansd script
/usr/sbin/8311-vlansd.sh &
RX_LOS



DROPBEAR="$ROOT_DIR/etc/init.d/dropbear"
DROPBEAR_HEAD=$(pcre2grep -B99999999 -M 'boot\(\)\s+\{\s+BOOT=1$' "$DROPBEAR")
DROPBEAR_FOOT=$(pcre2grep -A99999999 -M 'boot\(\)\s+\{\s+BOOT=1$' "$DROPBEAR" | tail -n +4)

rm -rfv "$ROOT_DIR/etc/dropbear"
ln -fsv "/ptconf/8311/.ssh" "$ROOT_DIR/root/.ssh"
ln -fsv "/ptconf/8311/dropbear" "$ROOT_DIR/etc/dropbear"

echo "$DROPBEAR_HEAD" > "$DROPBEAR"
cat >> "$DROPBEAR" <<'DROPBEAR_KEYS'

	# 8311 MOD: persistent server and client key
	DROPBEAR_RSA_KEY=$(uci -qc /ptconf/8311 get dropbear.rsa_key.value)
	DROPBEAR_PUBKEY=$(uci -qc /ptconf/8311 get dropbear.public_key.value)
	DROPBEAR_PUBKEY_BASE64=$(uci -qc /ptconf/8311 get dropbear.public_key.encryflag)

	[ -f "/ptconf/8311/dropbear" ] && rm -fv "/ptconf/8311/dropbear"
	mkdir -p /ptconf/8311 /ptconf/8311/dropbear /ptconf/8311/.ssh
	chmod 700 /ptconf/8311/dropbear /ptconf/8311/.ssh
	ln -fsv /ptconf/8311/.ssh/authorized_keys /ptconf/8311/dropbear/authorized_keys

	if [ -n "$DROPBEAR_RSA_KEY" ]; then
		echo "Migrating dropbear.rsa_key to /ptconf/8311/dropbear/dropbear_rsa_host_key" | tee -a /dev/console

		echo "$DROPBEAR_RSA_KEY" | base64 -d > /ptconf/8311/dropbear/dropbear_rsa_host_key
		chmod 600 /ptconf/8311/dropbear/dropbear_rsa_host_key
	fi

	if [ -n "$DROPBEAR_PUBKEY" ]; then
		echo "Migrating dropbear.public_key to /ptconf/8311/.ssh/authorized_keys" | tee -a /dev/console

		if [ "$DROPBEAR_PUBKEY_BASE64" = "1" ]; then
			echo "$DROPBEAR_PUBKEY" | base64 -d > /ptconf/8311/.ssh/authorized_keys
		else
			echo "$DROPBEAR_PUBKEY" > /ptconf/8311/.ssh/authorized_keys
		fi

		chmod 600 /ptconf/8311/.ssh/authorized_keys
	fi

DROPBEAR_KEYS
echo "$DROPBEAR_FOOT" >> "$DROPBEAR"


cat >> "$ROOT_DIR/etc/init.d/bfw_sysinit" <<'BFW_SYSINIT'


# 8311 MOD
boot() {
	# Remove persistent root
	PERSIST_ROOT=$(fw_printenv -n 8311_persist_root 2>/dev/null)
	if ! { [ "$PERSIST_ROOT" -eq "1" ] 2>/dev/null; }; then
		echo "8311_persist_root not enabled, checking bootcmd..." | tee -a /dev/console
		BOOTCMD=$(fw_printenv -n bootcmd 2>/dev/null)
		if ! { echo "$BOOTCMD" | grep -Eq '^\s*run\s+ubi_init\s*;\s*ubi\s+remove\s+rootfs_data\s*;\s*run\s+flash_flash\s*$'; }; then
			echo "Resetting bootcmd to default value and rebooting, set fwenv 8311_persist_root=1 to avoid this" | tee -a /dev/console

			fw_setenv bootcmd "run ubi_init;ubi remove rootfs_data;run flash_flash"
			fw_setenv bootcmd "run ubi_init;ubi remove rootfs_data;run flash_flash"

			reboot
			sleep 5
		fi
	fi

	# 8311 MOD: Ping host to help management work
	PING_HOST=$(fw_printenv -n 8311_ping_ip 2>/dev/null)
	if [ -z "$PING_HOST" ]; then
		ipaddr=$(fw_printenv -n 8311_ipaddr 2>/dev/null || echo "192.168.11.1")
        netmask=$(fw_printenv -n 8311_netmask 2>/dev/null || echo "255.255.255.0")

		IFS='.' read -r i1 i2 i3 i4 <<IPADDR
${ipaddr}
IPADDR
		IFS='.' read -r m1 m2 m3 m4 <<NETMASK
${netmask}
NETMASK

		# calculate the 2nd usable ip of the range (1st is the stick)
		PING_HOST=$(printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$(((i4 & m4) + 2))")
	fi

	echo "Starting ping to: $PING_HOST" | tee -a /dev/console
	ping -i 5 "$PING_HOST" > /dev/null 2>&1 < /dev/null &

	# 8311 MOD: fwenv to set Logical ONU ID
	LOID=$(fw_printenv -n 8311_loid 2>/dev/null | head -c 24)
	if [ -n "$LOID" ]; then
		echo "Setting PON Logical ONU ID to: $LOID" | tee -a /dev/console
		uci -q set omci.default.loid="$LOID"
	fi

	# 8311 MOD: fwenv to set Logical Password
	LPWD=$(fw_printenv -n 8311_lpwd 2>/dev/null | head -c 12)
	if [ -n "$LPWD" ]; then
		echo "Setting PON Logical Password to: $LPWD" | tee -a /dev/console
		uci -q set omci.default.lpwd="$LPWD"
	fi

	# set mib file from mib_file fwenv
	MIB_FILE=$(fw_printenv -n 8311_mib_file 2>/dev/null)
	if [ -n "$MIB_FILE" ]; then
		if [ -f "/etc/mibs/$MIB_FILE" ]; then
			MIB_FILE="/etc/mibs/$MIB_FILE"
		fi

		if [ -f "$MIB_FILE" ]; then
			echo "Setting OMCI MIB file: $MIB_FILE" | tee -a /dev/console
			uci -q set omci.default.mib_file="$MIB_FILE"
		fi
	fi
	MIB_FILE="${MIB_FILE:-"/etc/mibs/prx300_1U.ini"}"

	# fwenv for setting eth0_0 speed settings with ethtool
	ETH_SPEED=$(fw_printenv -n 8311_ethtool_speed 2>/dev/null)
	if [ -n "$ETH_SPEED" ]; then
		echo "Setting ethtool speed parameters: $ETH_SPEED" | tee -a /dev/console
		ethtool -s eth0_0 $ETH_SPEED
	fi

	# fwenv for setting the root account password hash
	ROOT_PWHASH=$(fw_printenv -n 8311_root_pwhash 2>/dev/null | sed 's#/#\\/#g')
	if [ -n "$ROOT_PWHASH" ]; then
		echo "Setting root password hash: $ROOT_PWHASH" | tee -a /dev/console
		sed -r "s/(root:)([^:]+)(:.+)/\1${ROOT_PWHASH}\3/g" -i /etc/shadow
	fi

	# fwenv to set hardware version (omci_pipe.sh meg 256 0)
	HW_VERSION=$(fw_printenv -n 8311_hw_ver 2>/dev/null | head -c 14)
	if [ -n "$HW_VERSION" ]; then
		echo "Setting PON hardware version: $HW_VERSION" | tee -a /dev/console
		uci -qc /ptrom/ptconf set sysinfo_conf.HardwareVersion=key
		uci -qc /ptrom/ptconf set sysinfo_conf.HardwareVersion.encryflag=0
		uci -qc /ptrom/ptconf set sysinfo_conf.HardwareVersion.value="$HW_VERSION"


		SYNC_CP_HW_VERSION=$(fw_printenv -n 8311_cp_hw_ver_sync 2>/dev/null)
		if [ "$SYNC_CP_HW_VERSION" -eq 1 ] 2>/dev/null; then
			echo "Setting PON Circuit Pack versions to: $HW_VERSION" | tee -a /dev/console
			sed -r "s#^(6\s+\S+\s+\S+\s+\S+\s+\"[^\"]+\"\s+)\"[^\"]+\"#\1\"${HW_VERSION}\"#g" -i "$MIB_FILE"
		fi
	fi

	# fwenv to change the slot presented to the OLT
	PON_SLOT=$(fw_printenv -n 8311_pon_slot 2>/dev/null)
	if [ "$PON_SLOT" -gt "1" ] 2>/dev/null && [ "$PON_SLOT" -le "254" ]; then
		PON_SLOT_HEX=$(printf '%.2x\n' "$PON_SLOT")
		sed -r "s/^(277\s+(\S+\s+){6})0x01/\10x${PON_SLOT_HEX}/g" -i "$MIB_FILE"
		sed -r "s/^(5|6)\s+0x0101/\1 0x01${PON_SLOT_HEX}/g" -i "$MIB_FILE"
		sed -r "s/^(([?!]\s+)?\d+)\s+0x0101/\1 0x${PON_SLOT_HEX}01/g" -i "$MIB_FILE"
	fi

	# commit uci changes
	[ -n "$(uci -qc /ptrom/ptconf changes sysinfo_conf)" ] && uci -qc /ptrom/ptconf commit sysinfo_conf
	[ -n "$(uci -q changes omci)" ] && uci -q commit omci


	start "$@"
}
BFW_SYSINIT

RC_LOCAL="$ROOT_DIR/etc/rc.local"

RC_LOCAL_HEAD=$(grep -P -B99999999 '^exit 0$' "$RC_LOCAL" | head -n -1)
RC_LOCAL_FOOT=$(grep -P -A99999999 '^exit 0$' "$RC_LOCAL")

echo "$RC_LOCAL_HEAD" > "$RC_LOCAL"
cat >> "$RC_LOCAL" <<'FAILSAFE'

# 8311 MOD: Failsafe, delay omcid start
DELAY=$(fw_printenv -n 8311_failsafe_delay 2>/dev/null)
[ "$DELAY" -ge 30 ] 2>/dev/null || DELAY=30
[ "$DELAY" -le 300 ] || DELAY=300
sleep "$DELAY" && [ ! -f /root/.failsafe ] && [ ! -f /tmp/.failsafe ] && [ ! -f /ptconf/.failsafe ] && /etc/init.d/omcid.sh start

FAILSAFE
echo "$RC_LOCAL_FOOT" >> "$RC_LOCAL"
chmod +x "$RC_LOCAL"


LIB_PON_SH="$ROOT_DIR/lib/pon.sh"
LIB_PON_SH_HEAD=$(grep -P -B99999999 '^pon_base_mac_get\(\)' "$LIB_PON_SH")
LIB_PON_SH_FOOT=$(grep -P -A99999999 '^\s+echo \$mac_addr$' "$LIB_PON_SH")

echo "$LIB_PON_SH_HEAD" > "$LIB_PON_SH"
cat >> "$LIB_PON_SH" <<'PONSH'
	# 8311 MOD: Use proper base MAC
	local serial_suffix=$(dd if=/sys/class/pon_mbox/pon_mbox0/device/eeprom50 bs=1 skip=72 count=8 2>/dev/null)
	local mac_addr="10:B3:6F:00:00:00"

	[ -n "$serial_suffix" ] && mac_addr="$(echo "$mac_addr" | head -c 5)$(echo "$serial_suffix" | sed -r 's/(..)/:\1/g')"
PONSH
echo "$LIB_PON_SH_FOOT" >> "$LIB_PON_SH"


IP_CONFIG="$ROOT_DIR/etc/uci-defaults/30-ip-config"
IP_CONFIG_HEAD=$(grep -P -B99999999 '^local ip=\$\(.+/proc/cmdline\)$' "$IP_CONFIG" | head -n -1)
IP_CONFIG_FOOT=$(grep -A99999999 'uci set network.$interface.ipaddr=' "$IP_CONFIG")

echo "$IP_CONFIG_HEAD" > "$IP_CONFIG"
cat >> "$IP_CONFIG" <<'UCI_IP_CONFIG'

# 8311 MOD: Configure management IP/subnet/gateway
local ipaddr=$(fw_printenv -n 8311_ipaddr 2>/dev/null || echo "192.168.11.1")
local netmask=$(fw_printenv -n 8311_netmask 2>/dev/null || echo "255.255.255.0")
local gateway=$(fw_printenv -n 8311_gateway 2>/dev/null || echo "$ipaddr")

uci set network.$interface.auto=1
UCI_IP_CONFIG
echo "$IP_CONFIG_FOOT" >> "$IP_CONFIG"


cat >> "$ROOT_DIR/etc/init.d/network" <<'INITD_NETWORK'


# 8311 MOD: Configure IP/subnet/gateway
boot() {
	local ipaddr=$(fw_printenv -n 8311_ipaddr 2>/dev/null || echo "192.168.11.1")
	local netmask=$(fw_printenv -n 8311_netmask 2>/dev/null || echo "255.255.255.0")
	local gateway=$(fw_printenv -n 8311_gateway 2>/dev/null || echo "$ipaddr")

	echo "Setting IP: $ipaddr, Netmask: $netmask, Gateway: $gateway" | tee -a /dev/console

	sed -r 's#(<param name="Ipaddr" .+ value=)"\S+"(></param>)#\1"'"$ipaddr"'"\2#g' -i /ptrom/ptconf/param_ct.xml
	sed -r 's#(<param name="SubnetMask" .+ value=)"\S+"(></param>)#\1"'"$netmask"'"\2#g' -i /ptrom/ptconf/param_ct.xml
	sed -r 's#(<param name="Gateway" .+ value=)"\S+"(></param>)#\1"'"$gateway"'"\2#g' -i /ptrom/ptconf/param_ct.xml

	start "$@"
}
INITD_NETWORK

cp -fv "scripts/8311-rx_los.sh" "scripts/8311-vlansd.sh" "scripts/8311-persist-root-password.sh" "$ROOT_DIR/usr/sbin/"
cp -fv "8311-xgspon-bypass/8311-detect-config.sh" "8311-xgspon-bypass/8311-fix-vlans.sh" "$ROOT_DIR/usr/sbin/"
ln -fsv "/usr/sbin/8311-detect-config.sh" "$ROOT_DIR/root/8311-detect-config.sh"
ln -fsv "/usr/sbin/8311-fix-vlans.sh" "$ROOT_DIR/root/8311-fix-vlans.sh"
mkdir -p "$ROOT_DIR/etc/crontabs"

touch "$ROOT_DIR/etc/crontabs/root"

sed -r 's#^(\s+)(start.+)$#\1\# 8311 MOD: Do not auto start omcid\n\1\# \2#g' -i "$ROOT_DIR/etc/init.d/omcid.sh"


sed -r 's#^(\s+)(.+ )(\|\| ubimkvol /dev/ubi0 -N rootfs_data)( .+$)#\1\# 8311 MOD: Always try to create rootfs_data at ID 6 first\n\1\2\3 -n 6\4 \3\4#g' -i "$ROOT_DIR/lib/preinit/06_create_rootfs_data"

OMCID="$ROOT_DIR/opt/intel/bin/omcid"
if check_file "$OMCID" "0aa64358a3afaa17b4edfed0077141981bc13322c7d1cf730abc251fae1ecbb1"; then
	echo "Patching '$OMCID'..."

	# omcid mod by up-n-atom to fix management with VEIP mode
	printf '\x00' | dd of="$OMCID" conv=notrunc seek=$((0x7F5C5)) bs=1 count=1 2>/dev/null

	# omcid mod by djGrrr to make default LOID and LPWD empty
	printf '\x00\x00\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0xF42F4)) bs=1 count=6 2>/dev/null
	printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00' | dd of="$OMCID" conv=notrunc seek=$((0xF4304)) bs=1 count=9 2>/dev/null

	expected_hash "$OMCID" "62925b4dd5ca2b097f914aa4fb26247e72c04f18e7c8a9e0263d31c9817ea1fc"
fi

# libponnet mod by rss to fix management with VEIP mode
LIBPONNET="$ROOT_DIR/usr/lib/libponnet.so.0.0.0"
if check_file "$LIBPONNET" "8075079231811f58dd4cec06ed84ff5d46a06e40b94c14263a56110edfa2a705"; then
	echo "Patching '$LIBPONNET'..."

	printf '\x00\x00' | dd of="$LIBPONNET" conv=notrunc seek=$((0x51B9A)) bs=1 count=2 2>/dev/null

	expected_hash "$LIBPONNET" "d76ac53305e0a4f2252c265c664480fe1a35c9b375b0d5e2e092a4d56f83f029"
fi

# libponhwal mod by rajkosto/djGrrr to fix Software and Hardware versions
LIBPONHWAL="$ROOT_DIR/ptrom/lib/libponhwal.so"
if check_file "$LIBPONHWAL" "f0e48ceba56c7d588b8bcd206c7a3a66c5c926fd1d69e6d9d5354bf1d34fdaf6"; then
	echo "Patching '$LIBPONHWAL'..."

	# patch ponhw_get_hardware_ver to use the correct string length
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x278CB)) bs=1 count=1 2>/dev/null

	# patch ponhw_get_software_ver to use the correct string length
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x277C7)) bs=1 count=1 2>/dev/null
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x27823)) bs=1 count=1 2>/dev/null

	# patch ponhw_get_equipment_id to use the correct string length
	printf '\x14' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x27647)) bs=1 count=1 2>/dev/null

	expected_hash "$LIBPONHWAL" "624aa5875a7bcf4d91a060e076475336622b267ff14b9c8fbb87df30fc889788"
fi

# libponhwal mod by djGrrr based on rajkosto's mod
if check_file "$LIBPONHWAL" "6af1b3b1fba25488fd68e5e2e2c41ab0e178bd190f0ba2617fc32bdfad21e4c4"; then
	echo "Patching '$LIBPONHWAL'..."

	# patch ponhw_get_hardware_ver to use the correct string length
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x2738B)) bs=1 count=1 2>/dev/null

	# patch ponhw_get_software_ver to use the correct string length
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x27287)) bs=1 count=1 2>/dev/null
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x272E3)) bs=1 count=1 2>/dev/null

	# patch ponhw_get_equipment_id to use the correct string length
	printf '\x14' | dd of="$LIBPONHWAL" conv=notrunc seek=$((0x27107)) bs=1 count=1 2>/dev/null

	expected_hash "$LIBPONHWAL" "36b20ed9c64de010e14543659302fdb85090efc49e48c193c2c156f6333afaac"
fi


VEIP_MIB="$ROOT_DIR/etc/mibs/prx300_1V.ini"
VEIP_HEAD=$(grep -P -B99999999 '^# Virtual Ethernet Interface Point$' "$VEIP_MIB" | head -n -1)
VEIP_FOOT=$(grep -P -A99999999 '^# Virtual Ethernet Interface Point$' "$VEIP_MIB")

echo "$VEIP_HEAD" > "$VEIP_MIB"
# Enable LCT Management interface in VEIP mode
cat >> "$VEIP_MIB" <<'VEIP_LCT'

# PPTP Ethernet UNI
? 11 0x0101 0 0 0 0x00 1 1 0 2000 0 0xffff 0 0 0 0 0

VEIP_LCT
echo "$VEIP_FOOT" >> "$VEIP_MIB"

OUT_BOOTCORE=$(realpath "$OUT_DIR/bootcore.bin")
[ "$BOOTCORE" = "$OUT_BOOTCORE" ] || cp -fv "$BOOTCORE" "$OUT_BOOTCORE"
OUT_KERNEL=$(realpath "$OUT_DIR/kernel.bin")
[ "$KERNEL" = "$OUT_KERNEL" ] || cp -fv "$KERNEL" "$OUT_KERNEL"

mksquashfs "$ROOT_DIR" "$ROOTFS" -all-root -noappend -comp xz -b 256K || _err "Error creating new rootfs image"
[ -n "$HEADER" ] && [ -f "$HEADER" ] && ./create.sh -i "$IMG_OUT" -H "$HEADER" -b "$BOOTCORE" -k "$KERNEL" -r "$ROOTFS"
