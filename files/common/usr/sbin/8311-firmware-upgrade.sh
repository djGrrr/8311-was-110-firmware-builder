#!/bin/sh
_err() {
	echo "$1" >&2
	exit ${2:-1}
}

_help() {
	printf -- 'Tool for validating and installing prx126-sfp-pon firmware upgrades.\n\n'
	printf -- 'Usage: %s [options] <firmware upgrade tar file>\n\n' "$0"
	printf -- 'Options:\n'
	printf -- '-v|--validate\t\tValidate images from the firmware upgrade tar file.\n'
	printf -- '-i|--install\t\tInstall images  from the firmware upgrade tar file to the inactive firmware bank.\n'
	printf -- '-r|--reboot\t\tReboot after a successful firmware upgrade.\n'
	printf -- '-y|--yes\t\tAnswer yes to any prompts.\n'
	printf -- '-h|--help\t\tThis help text.\n\n'
	printf -- '--\t\t\tDon'"'"'t process any further options, the next parameter is the firmware upgrade tar file.\n'
}

_yesno() {
	local DEFAULT=false
	[ "$1" = "y" ] && DEFAULT=true

	local yes
	read yes
	yes=$(echo "$yes" | tr 'YES' 'yes')

	if [ -n "$yes" ]; then
		[ "$yes" = "y" ] || [ "$yes" = "ye" ] || [ "$yes" = "yes" ]
	else
		$DEFAULT
	fi
}

VALIDATE=false
INSTALL=false
YES=false
REBOOT=false
TAR=
while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help)
			_help
			exit 0
		;;
		-v|--validate)
			VALIDATE=true
		;;
		
		-i|--install)
			INSTALL=true
		;;
		-y|--yes)
			YES=true
		;;
		-r|--reboot)
			REBOOT=true
		;;
		--)
			TAR="$2"
			break
		;;
		-*)
			_help
			exit 1
		;;
		*)
			if [ -n "$TAR" ]; then
				_help
				exit 1
			fi

			TAR="$1"
		;;
	esac
	shift
done

_lib_8311 2>/dev/null || . /lib/8311.sh

if ! $VALIDATE && ! $INSTALL; then
	VALIDATE=true
	INSTALL=true
fi

if [ -z "$TAR" ]; then
	_help
	exit 1
fi

if [ ! -r "$TAR" ]; then
	_err "Upgrade file '$TAR' not found."
fi

CONTROL=$(tar x -f "$TAR" -O -- control 2>/dev/null)
if [ -z "$CONTROL" ]; then
	_err "Invalid firmware upgrade tar, control file not found."
fi

control_var() {
	[ -n "$1" ] || return 1
	echo "$CONTROL" | grep "^$1=" | cut -d= -f2-
}

sha256() {
	sha256sum "$@" | awk '{print $1}'
}

ubi_default_order() {
	case "$1" in
		kernelA) echo "0"; ;;
		bootcoreA) echo "1"; ;;
		rootfsA) echo "2"; ;;
		kernelB) echo "3"; ;;
		bootcoreB) echo "4"; ;;
		rootfsB) echo "5"; ;;
		*) return 1; ;;
	esac
}

ubi_dev() {
	local NAME="$1"
	[ -n "$NAME" ] || _err "Must specify name for UBI volume name."
	VOL=$(ubinfo /dev/ubi0 -N "$NAME" 2>/dev/null | grep "Volume ID:" | awk '{print $3}')
	[ "$VOL" -ge 0 ] 2>/dev/null || return 1
	echo "/dev/ubi0_$VOL"
}

ubi_size() {
	local NAME="$1"
	[ -n "$NAME" ] || _err "Must specify name for UBI volume name."
	SIZE=$(ubinfo /dev/ubi0 -N "$NAME" 2>/dev/null | grep "Size:" | tr '(),' '   ' | awk '{print $4}')
	[ -n "$SIZE" ] || return 1
	echo "$SIZE"
}

ubi_create() {
	local NAME="$1"
	local SIZE="$2"
	local VOL="$3"

	echo "Creating $NAME UBI volume..."
	ubimkvol /dev/ubi0 -n "$VOL" -N "$NAME" -s "$SIZE" || ubimkvol /dev/ubi0 -n "$VOL" -N "$NAME" || _err "Error creating $NAME UBI volume."
}

ubi_resize() {
	local NAME="$1"
	local SIZE="$2"
	[ "$SIZE" -gt 0 ] 2>/dev/null || _err "Size of partition to resize must be > 0."

	echo "Resizing $NAME UBI volume to $SIZE bytes..."
	ubirsvol /dev/ubi0 -N "$NAME" -s "$SIZE" || _err "Error resizing $NAME UBI volume."
}

validate_image() {
	local VAR="$1"
	local FILE="$2"
	local NAME="$3"
	local SHA256=$(control_var "SHA256_$VAR")

	[ -z "$SHA256" ] && _err "$NAME hash not found in control file."
	echo -n "Validating $NAME image..."
	ACTUAL_SHA256=$(tar x -f "$TAR" -O -- "$FILE" 2>/dev/null | sha256)
	[ "$ACTUAL_SHA256" = "$SHA256" ] && echo " OK" || { echo " FAILED";  _err "Image $NAME hash '$ACTUAL_SHA256' does not match expected '$SHA256'."; }
}

install_image() {
	local VAR="$1"
	local FILE="$2"
	local NAME="$3"
	local UBI_VOLNAME="$4"
	
	local SHA256=$(control_var "SHA256_$VAR")
	local SIZE=$(control_var "SIZE_$VAR")

	[ -z "$SHA256" ] && _err "$NAME hash not found in control file."
	[ -z "$SIZE" ] && _err "$NAME file size not found in control file."

	local UBI=$(ubi_dev "$UBI_VOLNAME")
	local UBI_VOL=$(ubi_default_order "$UBI_VOLNAME")
	[ "$UBI_VOL" -ge 0 ] 2>/dev/null || _err "Invalid UBI volume '$UBI_VOLNAME'."
	if [ -z "$UBI" ]; then
		ubi_create "$UBI_VOLNAME" "$SIZE" "$UBI_VOL"
		UBI=$(ubi_dev "$UBI_VOLNAME")
		[ -n "$UBI" ] || _err "Error finding UBI volume '$UBI_VOLUME' after create."
	else
		UBI_SIZE=$(ubi_size "$UBI_VOLNAME")
		[ -n "$UBI_SIZE" ] || _err "Invalid UBI volume '$UBI_VOLNAME' while resizing."
		if [ "$UBI_SIZE" -lt "$SIZE" ]; then
			ubi_resize "$UBI_VOLNAME" "$SIZE"
		fi
	fi
	

	echo "Installing $NAME image to $UBI_VOLNAME ($UBI)..."
	tar x -f "$TAR" -O -- "$FILE" 2>/dev/null | ubiupdatevol -s "$SIZE" "$UBI" - || _err "Error installing $NAME to '$UBI'."
	echo -n "Validating installed $NAME image..."
	ACTUAL_SHA256=$(head -c "$SIZE" "$UBI" | sha256)
	[ "$ACTUAL_SHA256" = "$SHA256" ] && echo " OK" || { echo " FAILED";  _err "Installed image $NAME hash '$ACTUAL_SHA256' does not match expected '$SHA256'."; }
}

FW_VERSION=$(control_var FW_VERSION)
FW_REVISION=$(control_var FW_REVISION)
FW_VARIANT=$(control_var FW_VARIANT)

{ [ -n "$FW_VERSION" ] && [ -n "$FW_REVISION" ] && [ "$FW_VARIANT" ]; } || _err "Missing firmware version information."

echo "New Firmware:"
echo "Version: $FW_VERSION"
echo "Revision: $FW_REVISION"
echo "Variant: $FW_VARIANT"
echo

if $VALIDATE; then
	validate_image "KERNEL" "kernel.bin" "Kernel"
	validate_image "BOOTCORE" "bootcore.bin" "Bootcore"
	validate_image "ROOTFS" "rootfs.img" "RootFS"
	echo
fi

INSTALL_BANK=$(inactive_fwbank)
echo "Active firmware bank is $(active_fwbank), will install to bank $INSTALL_BANK."

if $INSTALL; then
	LOCK="/tmp/8311-firmware-upgrade.lock"
	(
		flock -n 10 ||  _err "Firmware upgrade already in progress."

		echo
		if ! $YES; then
			echo -n "Are you sure you want to install this firmware to bank $INSTALL_BANK? (y/N) "
			_yesno || exit 1
		fi

		install_image "KERNEL" "kernel.bin" "Kernel" "kernel$INSTALL_BANK"
		install_image "BOOTCORE" "bootcore.bin" "Bootcore" "bootcore$INSTALL_BANK"
		install_image "ROOTFS" "rootfs.img" "RootFS" "rootfs$INSTALL_BANK"

		echo
		if ! $YES; then
			echo -n "Firmware successfully installed into bank $INSTALL_BANK. Update commit_bank to $INSTALL_BANK? (Y/n) "
			_yesno y || exit 0
		fi

		fwenv_set "commit_bank" "$INSTALL_BANK" && echo "Set commit_bank to $INSTALL_BANK, reboot to boot new firmware." || _err "Error setting commit_bank to $INSTALL_BANK."
		echo

		if ! $YES && ! $REBOOT; then
			echo -n "Would you like to reboot to the new firmware now? (y/N) "
			_yesno || exit 0
			REBOOT=true
		fi

		if $REBOOT; then
			echo "Rebooting..."
			( sleep 3 && reboot; ) &
		fi

		rm -f "$LOCK"
	) 10>"$LOCK"
fi

exit 0
