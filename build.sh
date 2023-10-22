#!/bin/bash
set -xe
STOCK_IMAGE="${1:-"WAS-110_v19.07.8_maxlinear_1.0.12"}"
ROOT_DIR="rootfs/"
REAL_ROOT=$(realpath "$ROOT_DIR")


STOCK_IMG="stock/${STOCK_IMAGE}/rootfs.img"

if [ ! -f "$STOCK_IMG" ]; then
	echo "Stock image '$STOCK_IMG' not found." >&2
    exit 1
fi

rm -rfv "$ROOT_DIR"


sudo unsquashfs -d "$REAL_ROOT" "$STOCK_IMG"
USER=$(id -un)
GROUP=$(id -gn)

sudo chown -R "$USER:$GROUP" "$REAL_ROOT"


BFW_START="$ROOT_DIR/etc/init.d/bfw_start.sh"

BFW_HEAD=$(grep -P -B99999999 '^#set FXM_TXFAULT_EN$' "$BFW_START" | head -n -1)
BFW_CONSOLE=$(grep -P -A99999999 '^#set FXM_TXFAULT_EN$' "$BFW_START" | grep -P -B99999999 '^#set DYING GASP EN$' | head -n -1)
BFW_CONSOLE_HEAD=$(echo "$BFW_CONSOLE" | grep -P -B99999999 '^/ptrom/bin/gpio_cmd set 30 0$')
BFW_CONSOLE_FOOT=$(echo "$BFW_CONSOLE" | grep -P -A99999999 '^/ptrom/bin/gpio_cmd set 30 0$' | tail -n +2)
BFW_DYING_GASP=$(grep -P -A99999999 '^#set DYING GASP EN$' "$BFW_START" | grep -P -B99999999 '^pon 1pps_event_enable$' | head -n -1)
BFW_FOOT=$(grep -P -A99999999 '^pon 1pps_event_enable$' "$BFW_START")

echo "$BFW_HEAD" > "$BFW_START"
echo >> "$BFW_START"
echo "$BFW_DYING_GASP" >> "$BFW_START"
echo >> "$BFW_START"
echo "$BFW_CONSOLE_HEAD" >> "$BFW_START"
cat >> "$BFW_START" <<'CONSOLE_FWENV'

# 8311 MOD: fwenv for enabling UART
console_en=$(fw_printenv -n console_en 2>/dev/null)
if [ "$console_en" = "1" ]; then
    echo "fwenv console_en set console enable!!" | tee -a /dev/console
    /ptrom/bin/gpio_cmd set 30 1
fi
CONSOLE_FWENV
echo "$BFW_CONSOLE_FOOT" >> "$BFW_START"
echo >> "$BFW_START"
echo "$BFW_FOOT" >> "$BFW_START"

# Push messages about changes to UART to the console
sed -r 's#^(\s*echo \".+\!\!\")$#\1 | tee -a /dev/console#g' -i "$BFW_START"

#sed -r 's#(\#set FXM_TXFAULT_EN)$#\# 8311 MOD: fwenv for setting eth0_0 speed settings with ethtool\nETH_SPEED=$(fw_printenv -n ethtool_speed 2>/dev/null)\n[ -n "$ETH_SPEED" ] \&\& ethtool -s eth0_0 $ETH_SPEED\n\n\1#g' -i "$BFW_START"
#sed -r 's#(\#set FXM_TXFAULT_EN)$#\# 8311 MODL fwenv for setting the root account password hash\nROOT_PWHASH=$(fw_printenv -n root_pwhash 2>/dev/null)\n[ -n \"$ROOT_PWHASH\" \] \&\& sed -r \"s/(root:)([^:]+)(:.+)/\\1${ROOT_PWHASH}\\3/g\" -i /etc/shadow\n\n\1#g' -i "$BFW_START"
#sed -r 's/^(#set FXM_TXFAULT_EN)$/# 8311 MOD: Automatically bring up the lct interface\nifup lct\n\n\1/g' -i "$BFW_START"


DROPBEAR="$ROOT_DIR/etc/init.d/dropbear"
DROPBEAR_HEAD=$(pcre2grep -B99999999 -M 'boot\(\)\s+\{$' "$DROPBEAR")
DROPBEAR_FOOT=$(pcre2grep -A99999999 -M 'boot\(\)\s+\{$' "$DROPBEAR" | tail -n +3)

echo "$DROPBEAR_HEAD" > "$DROPBEAR"
cat >> "$DROPBEAR" <<'DROPBEAR_KEYS'
	# 8311 MOD: persistent server and client key
	mkdir -p /ptconf/8311
	touch /ptconf/8311/dropbear

	DROPBEAR_RSA_KEY=$(uci -qc /ptconf/8311 get dropbear.rsa_key.value)
	if [ -n "$DROPBEAR_RSA_KEY" ]; then
		echo "$DROPBEAR_RSA_KEY" | base64 -d > /etc/dropbear/dropbear_rsa_host_key
		chmod 600 /etc/dropbear/dropbear_rsa_host_key
	fi

	DROPBEAR_PUBKEY=$(uci -qc /ptconf/8311 get dropbear.public_key.value)
	if [ -n "$DROPBEAR_PUBKEY" ]; then
        BASE64=$(uci -qc /ptconf/8311 get dropbear.public_key.encryflag)
        if [ "$BASE64" = "1" ]; then
			echo "$DROPBEAR_PUBKEY" | base64 -d > /root/.ssh/id_dropbear
        else
	        echo "$DROPBEAR_PUBKEY" > /root/.ssh/id_dropbear
		fi

		chmod 600 /root/.ssh/id_dropbear
	fi

DROPBEAR_KEYS
echo "$DROPBEAR_FOOT" >> "$DROPBEAR"

#sed -r 's#^(\tBOOT=1)$#\1\n\n\t\# 8311 MOD: persistent server key\n\tmkdir -p /ptconf/8311\n\tDROPBEAR_RSA_KEY=$(uci -qc /ptconf/8311 get dropbear.rsa_key.value)\n\tif [ -n \"$DROPBEAR_RSA_KEY\" ]; then\n\t\techo \"$DROPBEAR_RSA_KEY\" | base64 -d > /etc/dropbear/dropbear_rsa_host_key\n\t\tchmod 600 /etc/dropbear/dropbear_rsa_host_key\n\tfi\n#g' -i "$DROPBEAR"

cat >> "$ROOT_DIR/etc/init.d/bfw_sysinit" <<'BFW_SYSINIT'


# 8311 MOD
boot() {
	# set mib file from mib_file fwenv
	MIB_FILE=$(fw_printenv -n mib_file 2>/dev/null)
	if [ -n "$MIB_FILE" ]; then
		if [ -f "/etc/mibs/$MIB_FILE" ]; then
			MIB_FILE="/etc/mibs/$MIB_FILE"
		fi

		if [ -f "$MIB_FILE" ]; then
			uci set omci.default.mib_file="$MIB_FILE"
			uci commit omci
		fi
	fi

	# fwenv for setting eth0_0 speed settings with ethtool
	ETH_SPEED=$(fw_printenv -n ethtool_speed 2>/dev/null)
	if [ -n "$ETH_SPEED" ]; then
		ethtool -s eth0_0 $ETH_SPEED
	fi

	# fwenv for setting the root account password hash
	ROOT_PWHASH=$(fw_printenv -n root_pwhash 2>/dev/null)
	if [ -n "$ROOT_PWHASH" ]; then
		sed -r "s/(root:)([^:]+)(:.+)/\1${ROOT_PWHASH}\3/g" -i /etc/shadow
	fi

	# fwenv to set hardware version (omci_pipe.sh meg 256 0)
	HW_VERSION=$(fw_printenv -n version 2>/dev/null)
	if [ -n "$HW_VERSION" ]; then
		uci -qc /ptrom/ptconf set sysinfo_conf.HardwareVersion.value="$HW_VERSION"
	fi

	# fwenv to set software version (omci_pipe.sh meg 7 0)
	SW_VERSION=$(fw_printenv -n img_version 2>/dev/null)
    if [ -n "$SW_VERSION" ]; then
		uci -qc /ptrom/ptconf set sysinfo_conf.SoftwareVersion.value="$SW_VERSION"
	fi

    CHANGES=$(uci -qc /ptrom/ptconf changes sysinfo_conf)
    if [ -n "$CHANGES" ]; then
		uci -qc /ptrom/ptconf commit sysinfo_conf
    fi

	EQUIPMENT_ID=$(fw_printenv -n equipment_id 2>/dev/null)
    if [ -n "$EQUIPMENT_ID" ]; then	
		uci -qc /ptconf/device_info set WAS-110-XS.devicetype.value="$EQUIPMENT_ID"
        uci -qc /ptconf/device_info commit WAS-110-XS
	fi
}
BFW_SYSINIT

RC_LOCAL="$ROOT_DIR/etc/rc.local"
sed -r 's#(exit 0)#\# MOD: Failsafe, delay omcid start\nsleep 30 \&\& [ ! -f /root/.failsafe ] \&\& [ ! -f /tmp/.failsafe ] \&\& [ ! -f /ptconf/.failsafe ] \&\& /etc/init.d/omcid.sh start\n\n\1#g' -i "$RC_LOCAL"
chmod +x "$RC_LOCAL"

cat >> "$ROOT_DIR/etc/uci-defaults/30-ip-config" <<'UCI_IP_CONFIG'

# 8311 MOD: Make LCT interface come up automatically
uci set network.$interface.auto=1
UCI_IP_CONFIG

cp -fv "bell-xgspon-bypass/detect-bell-config.sh" "bell-xgspon-bypass/fix-bell-vlans.sh" "$ROOT_DIR/root/"
mkdir -p "$ROOT_DIR/etc/crontabs"

cat > "${ROOT_DIR}etc/crontabs/root" <<'CRONTAB'
* * * * * /root/fix-bell-vlans.sh
CRONTAB

rm -fv "$ROOT_DIR/etc/rc.d/S85omcid.sh"

rm -rfv "out"
mkdir "out"

cp -fv "stock/${STOCK_IMAGE}/kernel.img" "out/kernel.img"
cp -fv "stock/${STOCK_IMAGE}/bootcore.img" "out/bootcore.img"

IMG="out/rootfs.img"
mksquashfs "$ROOT_DIR" "$IMG" -all-root -noappend -comp xz -b 256K

