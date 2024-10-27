#!/bin/bash
_help() {
	printf -- 'Tool for building new modded WAS-110 firmware images\n\n'
	printf -- 'Usage: %s [options]\n\n' "$0"
	printf -- 'Options:\n'
	printf -- '-i --image <filename>\t\tSpecify stock local upgrade image file of BFW firmware.\n'
	printf -- '-I --image-dir <dir>\t\tSpecify stock image directory of the basic firmware (must contain bootcore.bin, kernel.bin, and rootfs.img).\n'
	printf -- '-o --image-out <filename>\tSpecify local upgrade image file to output.\n'
	printf -- '-O --tar-out <filename>\t\tSpecify local upgrade tar file to output.\n'
	printf -- '-V --image-version <version>\tSpecify custom image version string.\n'
	printf -- '-r --image-revision <revision>\tSpecify custom image revision string.\n'
	printf -- '-w --basic\t\t\tBuild a basic variant image.\n'
	printf -- '-W --bfw\t\t\tBuild a bfw variant image.\n'
	printf -- '-k --basic-kernel\t\tBuild image using the basic kernel.\n'
	printf -- '-K --bfw-kernel\t\t\tBuild image using the bfw kernel.\n'
	printf -- '-b --basic-bootcore\t\tBuild image using the basic bootcore.\n'
	printf -- '-B --bfw-bootcore\t\tBuild image using the bfw bootcore.\n'
	printf -- '-R --release\t\tCreate release archive files.\n'

	printf -- '-h --help\t\t\tThis help text\n'
}

IMGFILE=
IMGDIR=
BASE_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
TOOLS_DIR="$BASE_DIR/tools"
OUT_DIR="$BASE_DIR/out"
LIB_DIR="$BASE_DIR/lib"
IMG_OUT=""
TAR_OUT=""
FW_VARIANT="basic"
BOOTCORE_VARIANT=""
FW_VER=""
KERNEL_VARIANT=""
RELEASE=false

while [ $# -gt 0 ]; do
	case "$1" in
		-i|--bfw-image-file)
			IMGFILE="$2"
			shift
		;;
		-I|--basic-image-dir)
			IMGDIR="$2"
			shift
		;;
		-o|--image-out)
			IMG_OUT="$2"
			shift
		;;
		-o|--tar-out)
			TAR_OUT="$2"
			shift
		;;
		-V|--image-version)
			FW_VER="$2"
			shift
		;;
		-r|--image-revision)
			FW_REV="$2"
			shift
		;;
		-w|--basic)
			FW_VARIANT="basic"
		;;
		-W|--bfw)
			FW_VARIANT="bfw"
		;;
		-k|--basic-kernel)
			KERNEL_VARIANT="basic"
		;;
		-K|--bfw-kernel)
			KERNEL_VARIANT="bfw"
		;;
		-b|--basic-bootcore)
			BOOTCORE_VARIANT="basic"
		;;
		-B|--bfw-bootcore)
			BOOTCORE_VARIANT="bfw"
		;;
		-R|--release)
			RELEASE=true
		;;
		-h|--help)
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
	{ [ -n "$1" ] &&  sha256sum "$1" || sha256sum; } | awk '{print $1}'
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
GIT_DIFF="$(git diff HEAD)"
GIT_TAG=$(git tag --points-at HEAD | grep -P '^v\d+\.\d+\.\d+' | tr '-' '~' | sort -V -r | tr '~' '-' | head -n1)
GIT_EPOCH=$(git log -1 --format="%at")
GIT_EPOCH=${GIT_EPOCH:-$(date '+%s')}

FW_FW_SUFFIX=""
FW_VER="${FW_VER:-${GIT_TAG:-""}}"
[ -n "$GIT_DIFF" ] && FW_SUFFIX="~$(echo "$GIT_DIFF" | sha256 | head -c 7)"
[ -n "$FW_VER" ] && FW_VERSION="${FW_VER}${FW_SUFFIX}" || { FW_VER="dev"; FW_VERSION="dev"; }

FW_REV="${FW_REV:-$GIT_HASH}"
FW_REVISION="$FW_REV$FW_SUFFIX"

set -e

if [ -n "$IMGFILE" ]; then
	IMG_FILE=$(realpath "$IMGFILE")
	[ -f "$IMG_FILE" ] || _err "Image file '$IMG_FILE' does not exist."

	HEADER="$OUT_DIR/header.bin"
else
	_err "Must specify --bfw-image-file"
fi

if [ -n "$IMGDIR" ] && [ -d "$IMGDIR" ]; then
	IMG_DIR=$(realpath "$IMGDIR")
	[ -d "$IMG_DIR" ] || _err "Image directory '$IMG_DIR' does not exist."
else
	_err "Muat specify --basic-image-dir"
fi

rm -rfv "$OUT_DIR"
mkdir -pv "$OUT_DIR"

KERNEL_BFW="$OUT_DIR/kernel-bfw.bin"
KERNEL_BASIC="$IMG_DIR/kernel.bin"

BOOTCORE_BFW="$OUT_DIR/bootcore-bfw.bin"
BOOTCORE_BASIC="$IMG_DIR/bootcore.bin"

ROOTFS_BFW="$OUT_DIR/rootfs-bfw.img"
ROOTFS_BASIC="$IMG_DIR/rootfs.img"

KERNEL_VARIANT="${KERNEL_VARIANT:-$FW_VARIANT}"
BOOTCORE_VARIANT="${BOOTCORE_VARIANT:-$FW_VARIANT}"

[ "$KERNEL_VARIANT" = "bfw" ] && KERNEL="$KERNEL_BFW" || KERNEL="$KERNEL_BASIC"
[ "$BOOTCORE_VARIANT" = "bfw" ] && BOOTCORE="$BOOTCORE_BFW" || BOOTCORE="$BOOTCORE_BASIC"

./extract.sh -i "$IMGFILE" -H "$HEADER" -b "$BOOTCORE_BFW" -k "$KERNEL_BFW" -r "$ROOTFS_BFW" || _err "Error extracting image '$IMG_FILE'"


echo

ROOTFS="$OUT_DIR/rootfs.img"
ROOTFS_RESET="$OUT_DIR/rootfs-reset.img"

[ -f "$HEADER" ] || _err "Header file '$HEADER' does not exist."
[ -f "$BOOTCORE" ] || _err "Bootcore file '$BOOTCORE' does not exist."
[ -f "$KERNEL" ] || _err "Kernel file '$KERNEL' does not exist."
[ -f "$ROOTFS_BFW" ] || _err "RootFS file '$ROOTFS_BFW' does not exist."
[ -f "$ROOTFS_BASIC" ] || _err "RootFS file '$ROOTFS_BASIC' does not exist."

ROOT_BASE=$(realpath -s "./rootfs")
ROOT_BFW="${ROOT_BASE}-bfw"
ROOT_BASIC="${ROOT_BASE}-basic"

ROOT_DIR="${ROOT_BASE}-${FW_VARIANT}"

rm -rfv "$ROOT_BASE" "$ROOT_BFW" "$ROOT_BASIC"

sudo unsquashfs -d "$ROOT_BFW" "$ROOTFS_BFW" || _err "Error unsquashifying bfw RootFS image '$ORIG_ROOTFS'"
sudo unsquashfs -d "$ROOT_BASIC" "$ROOTFS_BASIC" || _err "Error unsquashifying basic RootFS image '$ORIG_ROOTFS'"

ln -s "rootfs-${FW_VARIANT}" "$ROOT_BASE"

[ -d "$ROOT_BFW/ptrom" ] || _err "/ptrom not found in bfw rootfs"
[ -d "$ROOT_BASIC/ptrom" ] && _err "/ptrom found in basic rootfs"

USER=$(id -un)
GROUP=$(id -gn)

sudo chown -R "$USER:$GROUP" "$ROOT_BASIC" "$ROOT_BFW"

FW_LONG_VERSION="${FW_VER}_${FW_VARIANT}_${FW_REV}${FW_SUFFIX}"

. mods/binary-mods.sh

. mods/pre-common-mods.sh

. "mods/${FW_VARIANT}-mods.sh"
[ "$FW_VARIANT" = "basic" ] && . mods/basic-i18n.sh

. mods/common-mods.sh

VERSION_FILE="$ROOT_DIR/etc/8311_version"
cat > "$VERSION_FILE" <<8311_VER
FW_VER=$FW_VER
FW_VERSION=$FW_VERSION
FW_LONG_VERSION=$FW_LONG_VERSION
FW_REV=$FW_REV
FW_REVISION=$FW_REVISION
FW_VARIANT=$FW_VARIANT
FW_SUFFIX=$FW_SUFFIX
8311_VER


REAL_OUT=$(realpath "$OUT_DIR")

OUT_BOOTCORE="$REAL_OUT/bootcore.bin"
[ "$BOOTCORE" = "$OUT_BOOTCORE" ] || cp -fv "$BOOTCORE" "$OUT_BOOTCORE"
OUT_KERNEL="$REAL_OUT/kernel.bin"
[ "$KERNEL" = "$OUT_KERNEL" ] || cp -fv "$KERNEL" "$OUT_KERNEL"

IMG_OUT="${IMG_OUT:-"$REAL_OUT/local-upgrade.img"}"
TAR_OUT="${TAR_OUT:-"$REAL_OUT/local-upgrade.tar"}"

mksquashfs "$ROOT_DIR" "$ROOTFS" -all-root -noappend -no-xattrs -comp xz -b 256K -all-time "$GIT_EPOCH" -mkfs-time "$GIT_EPOCH" || _err "Error creating new rootfs image"

. mods/reset-mods.sh

mksquashfs "$ROOT_DIR" "$ROOTFS_RESET" -all-root -noappend -no-xattrs -comp xz -b 256K -all-time "$GIT_EPOCH" -mkfs-time "$GIT_EPOCH" || _err "Error creating new factory reset rootfs image"

touch -d "@$GIT_EPOCH" "$ROOTFS" "$ROOTFS_RESET"
OUT_UROOTFS="$REAL_OUT/urootfs.img"
OUT_UROOTFS_RESET="$REAL_OUT/urootfs-reset.img"
SOURCE_DATE_EPOCH="$GIT_EPOCH" mkimage -A MIPS -O Linux -T filesystem -C none -n "$FW_LONG_VERSION" -d "$ROOTFS" "$OUT_UROOTFS"
SOURCE_DATE_EPOCH="$GIT_EPOCH" mkimage -A MIPS -O Linux -T filesystem -C none -n "MC Factory Reset $FW_VER" -d "$ROOTFS_RESET" "$OUT_UROOTFS_RESET"

#OUT_UMULTI="$REAL_OUT/uMulti.img"
#mkimage -A MIPS -O Linux -T multi -C none -n "MC $FW_LONG_VERSION" -d "$OUT_KERNEL:$OUT_BOOTCORE:$OUT_UROOTFS" "$OUT_UMULTI"

OUT_MCUPG="$REAL_OUT/multicast_upgrade.img"
cat "$OUT_KERNEL" "$OUT_BOOTCORE" "$OUT_UROOTFS" > "$OUT_MCUPG"

OUT_MCRESET="$REAL_OUT/multicast_reset.img"
cat "$OUT_KERNEL" "$OUT_BOOTCORE" "$OUT_UROOTFS_RESET" > "$OUT_MCRESET"

touch -d "@$GIT_EPOCH" "$OUT_MCUPG" "$OUT_MCRESET"

CREATE=("-b" "$OUT_BOOTCORE" "-k" "$OUT_KERNEL" "-r" "$ROOTFS" -D "@$GIT_EPOCH")
./create.sh --basic -i "$TAR_OUT" -F "$VERSION_FILE" "${CREATE[@]}"
./create.sh --bfw -i "$IMG_OUT" -V "$FW_VER" -L "$FW_LONG_VERSION" -H "$HEADER" "${CREATE[@]}"

rm -fv "$HEADER" "$KERNEL_BFW" "$BOOTCORE_BFW" "$ROOTFS_BFW" "$OUT_UROOTFS" "$OUT_UROOTFS_RESET" "$ROOTFS_RESET"

./wholeImage.sh "$GIT_EPOCH"

if $RELEASE; then
	cd "$REAL_OUT"
	REL_NAME="WAS-110_8311_firmware_mod_${FW_VERSION}_${FW_VARIANT}"
	7z a -md=128m -mx=9 -ms=on -mmt=on -mmtf=on -m0=LZMA2 "$REL_NAME.7z" -- "local-upgrade.tar" "local-upgrade.img" "multicast_upgrade.img" "multicast_reset.img" "bootcore.bin" "kernel.bin" "rootfs.img" "whole-image.img"
	cd "$BASE_DIR"
	cat "files/7z/7zsd_LZMA2_upx.sfx" "files/7z/was-110.cfg" "$REAL_OUT/$REL_NAME.7z" > "$REAL_OUT/$REL_NAME.exe"
fi

echo "Firmware build $FW_LONG_VERSION complete."
