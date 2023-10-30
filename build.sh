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


BFW_START="$ROOT_DIR/etc/init.d/bfw_start.sh"


# Push messages about changes to UART to the console
sed -r 's#^(\s*echo \".+\!\!\")$#\1 | tee -a /dev/console#g' -i "$BFW_START"

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
console_en=$(fw_printenv -n 8311_console_en 2>/dev/null || fw_printenv -n console_en 2>/dev/null)
if [ "$console_en" = "1" ]; then
    echo "fwenv console_en set console enable!!" | tee -a /dev/console
    /ptrom/bin/gpio_cmd set 30 1
fi
CONSOLE_FWENV
echo "$BFW_CONSOLE_FOOT" >> "$BFW_START"

# Don't set console GPIO til the setting is determined
sed -r 's#/ptrom/bin/gpio_cmd set 30 (0|1)$#CONSOLE_EN=\1#g' -i "$BFW_START"

cat >> "$BFW_START" <<'CONSOLE_SET'

l# 8311 MOD: Enable or Disable UART TX
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

	EQUIPMENT_ID=$(fw_printenv -n 8311_equipment_id 2>/dev/null || fw_printenv -n equipment_id 2>/dev/null)
	if [ -n "$EQUIPMENT_ID" ]; then
		uci -qc /tmp set deviceinfo.devicetype.value="$EQUIPMENT_ID"
		uci -qc /tmp commit deviceinfo
	fi
) &
EQUIPMENTID_MOD


DROPBEAR="$ROOT_DIR/etc/init.d/dropbear"
DROPBEAR_HEAD=$(pcre2grep -B99999999 -M 'boot\(\)\s+\{\s+BOOT=1$' "$DROPBEAR")
DROPBEAR_FOOT=$(pcre2grep -A99999999 -M 'boot\(\)\s+\{\s+BOOT=1$' "$DROPBEAR" | tail -n +4)

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
		mkdir -p /root/.ssh
		chmod 700 /root/.ssh
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


cat >> "$ROOT_DIR/etc/init.d/bfw_sysinit" <<'BFW_SYSINIT'


# 8311 MOD
boot() {
	# set mib file from mib_file fwenv
	MIB_FILE=$(fw_printenv -n 8311_mib_file 2>/dev/null || fw_printenv -n mib_file 2>/dev/null)
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
	ETH_SPEED=$(fw_printenv -n 8311_ethtool_speed 2>/dev/null || fw_printenv -n ethtool_speed 2>/dev/null)
	if [ -n "$ETH_SPEED" ]; then
		ethtool -s eth0_0 $ETH_SPEED
	fi

	# fwenv for setting the root account password hash
	ROOT_PWHASH=$(fw_printenv -n 8311_root_pwhash 2>/dev/null || fw_printenv -n root_pwhash 2>/dev/null)
	if [ -n "$ROOT_PWHASH" ]; then
		sed -r "s/(root:)([^:]+)(:.+)/\1${ROOT_PWHASH}\3/g" -i /etc/shadow
	fi

	# fwenv to set hardware version (omci_pipe.sh meg 256 0)
	HW_VERSION=$(fw_printenv -n 8311_hw_ver 2>/dev/null || fw_printenv -n version 2>/dev/null)
	if [ -n "$HW_VERSION" ]; then
		uci -qc /ptrom/ptconf set sysinfo_conf.HardwareVersion=key
		uci -qc /ptrom/ptconf set sysinfo_conf.HardwareVersion.encryflag=0
		uci -qc /ptrom/ptconf set sysinfo_conf.HardwareVersion.value="$HW_VERSION"
	fi

	# fwenvs to set software versions (omci_pipe.sh meg 7 0/1)
	SW_VERSION_A=$(fw_printenv -n 9311_sw_verA 2>/dev/null)
	if [ -n "$SW_VERSION_A" ]; then
        uci -qc /ptconf set sysinfo_conf.SoftwareVersion_A=key
        uci -qc /ptconf set sysinfo_conf.SoftwareVersion_A.encryflag=0
		uci -qc /ptconf set sysinfo_conf.SoftwareVersion_A.value="$SW_VERSION_A"
	fi

	SW_VERSION_B=$(fw_printenv -n 9311_sw_verB 2>/dev/null)
	if [ -n "$SW_VERSION_B" ]; then
		uci -qc /ptconf set sysinfo_conf.SoftwareVersion_B=key
		uci -qc /ptconf set sysinfo_conf.SoftwareVersion_B.encryflag=0
		uci -qc /ptconf set sysinfo_conf.SoftwareVersion_B.value="$SW_VERSION_B"
	fi

	SW_VERSION=$(fw_printenv -n 9311_sw_ver 2>/dev/null || fw_printenv -n img_version 2>/dev/null)
	if [ -n "$SW_VERSION" ]; then
		uci -qc /ptrom/ptconf set sysinfo_conf.SoftwareVersion=key
		uci -qc /ptrom/ptconf set sysinfo_conf.SoftwareVersion.encryflag=0
		uci -qc /ptrom/ptconf set sysinfo_conf.SoftwareVersion.value="$SW_VERSION"
	fi

	# commit uci changes
	[ -n "$(uci -qc /ptrom/ptconf changes sysinfo_conf)" ] && uci -qc /ptrom/ptconf commit sysinfo_conf
	[ -n "$(uci -qc /ptconf changes sysinfo_conf)" ] && uci -qc /ptconf commit sysinfo_conf


	start "$@"
}
BFW_SYSINIT

RC_LOCAL="$ROOT_DIR/etc/rc.local"

RC_LOCAL_HEAD=$(grep -P -B99999999 '^exit 0$' "$RC_LOCAL" | head -n -1)
RC_LOCAL_FOOT=$(grep -P -A99999999 '^exit 0$' "$RC_LOCAL")

echo "$RC_LOCAL_HEAD" > "$RC_LOCAL"
cat >> "$RC_LOCAL" <<'FAILSAFE'

# MOD: Failsafe, delay omcid start
DELAY=$(fw_printenv -n 8311_failsafe_delay 2>/dev/null || fw_printenv -n failsafe_delay 2>/dev/null)
[ "$DELAY" -ge 30 ] 2>/dev/null || DELAY=30
[ "$DELAY" -le 300 ] || DELAY=300
sleep "$DELAY" && [ ! -f /root/.failsafe ] && [ ! -f /tmp/.failsafe ] && [ ! -f /ptconf/.failsafe ] && /etc/init.d/omcid.sh start

FAILSAFE
echo "$RC_LOCAL_FOOT" >> "$RC_LOCAL"
chmod +x "$RC_LOCAL"

cat >> "$ROOT_DIR/etc/uci-defaults/30-ip-config" <<'UCI_IP_CONFIG'

# 8311 MOD: Make LCT interface come up automatically
uci set network.$interface.auto=1
UCI_IP_CONFIG

cp -fv "8311-xgspon-bypass/8311-detect-config.sh" "8311-xgspon-bypass/8311-fix-vlans.sh" "$ROOT_DIR/root/"
mkdir -p "$ROOT_DIR/etc/crontabs"

cat > "$ROOT_DIR/etc/crontabs/root" <<'CRONTAB'
* * * * * /root/8311-fix-vlans.sh
CRONTAB

rm -fv "$ROOT_DIR/etc/rc.d/S85omcid.sh"

# libponhwal mod by rajkosto to fix Software and Hardware versions
LIBPONHWAL="$ROOT_DIR/ptrom/lib/libponhwal.so"
if [ -f "$LIBPONHWAL" ] && [ "$(sha256sum "$LIBPONHWAL" | awk '{print $1}')" = "f0e48ceba56c7d588b8bcd206c7a3a66c5c926fd1d69e6d9d5354bf1d34fdaf6" ]; then
	echo "Patching '$LIBPONHWAL'..."

	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=161995 bs=1 count=1 2>/dev/null
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=161735 bs=1 count=1 2>/dev/null
	printf '\x0E' | dd of="$LIBPONHWAL" conv=notrunc seek=161827 bs=1 count=1 2>/dev/null

	EXPECTED_HASH="0317af1e420f6e996946dbb8151a6616a10b76ea0640203aa4d80ed95c6f4299"
	FINAL_HASH=$(sha256sum "$LIBPONHWAL" | awk '{print $1}')
	if ! [ "$FINAL_HASH" = "$EXPECTED_HASH" ]; then
		echo "Final '$LIBPONHWAL' SHA256 hash '$FINAL_HASH' != '$EXPECTED_HASH'" >&2
		exit 1
	fi
fi

OUT_BOOTCORE=$(realpath "$OUT_DIR/bootcore.bin")
[ "$BOOTCORE" = "$OUT_BOOTCORE" ] || cp -fv "$BOOTCORE" "$OUT_BOOTCORE"
OUT_KERNEL=$(realpath "$OUT_DIR/kernel.bin")
[ "$KERNEL" = "$OUT_KERNEL" ] || cp -fv "$KERNEL" "$OUT_KERNEL"

mksquashfs "$ROOT_DIR" "$ROOTFS" -all-root -noappend -comp xz -b 256K || _err "Error creating new rootfs image"
[ -n "$HEADER" ] && [ -f "$HEADER" ] && ./create.sh -i "$IMG_OUT" -H "$HEADER" -b "$BOOTCORE" -k "$KERNEL" -r "$ROOTFS"
