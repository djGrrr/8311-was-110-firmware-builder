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

FW_VARIANT="basic"

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
		-V|--image-version)
			FW_VER="$2"
			shift
		;;
		-b|--basic)
			FW_VARIANT="basic"
		;;
		-w|--bfw)
			FW_VARIANT="bfw"
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
	sha256sum "$1" | awk '{print $1}'
}

file_size() {
	stat -c '%s' "$1"
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
[ -n "$GIT_TAG" ] && FW_VERSION="${GIT_TAG}${FW_SUFFIX}" || FW_VERSION="dev"

FW_REV="$GIT_HASH"
FW_REVISION="$GIT_HASH$FW_SUFFIX"

FW_VER="${FW_VER:-"${GIT_TAG:-"dev"}"}"

set -e

if [ -n "$IMGFILE" ]; then
	IMG_FILE=$(realpath "$IMGFILE")
	[ -f "$IMG_FILE" ] || _err "Image file '$IMG_FILE' does not exist."

	HEADER="$OUT_DIR/header.bin"
else
	__err "Must specify --bfw-image-file"
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

if [ "$FW_VARIANT" = "bfw" ]; then
	BOOTCORE="$BOOTCORE_BFW"
	KERNEL="$KERNEL_BFW"
else
	BOOTCORE="$BOOTCORE_BASIC"
	KERNEL="$KERNEL_BASIC"
fi

./extract.sh -i "$IMGFILE" -H "$HEADER" -b "$BOOTCORE_BFW" -k "$KERNEL_BFW" -r "$ROOTFS_BFW" || _err "Error extracting image '$IMG_FILE'"


echo

ROOTFS="$OUT_DIR/rootfs.img"

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


. mods/common-mods.sh

. mods/binary-mods.sh

. "mods/${FW_VARIANT}-mods.sh"


REAL_OUT=$(realpath "$OUT_DIR")
OUT_BOOTCORE="$REAL_OUT/bootcore.bin"
[ "$BOOTCORE" = "$OUT_BOOTCORE" ] || cp -fv "$BOOTCORE" "$OUT_BOOTCORE"
OUT_KERNEL="$REAL_OUT/kernel.bin"
[ "$KERNEL" = "$OUT_KERNEL" ] || cp -fv "$KERNEL" "$OUT_KERNEL"

mksquashfs "$ROOT_DIR" "$ROOTFS" -all-root -noappend -no-xattrs -comp xz -b 256K || _err "Error creating new rootfs image"
[ -n "$HEADER" ] && [ -f "$HEADER" ] && ./create.sh -i "$IMG_OUT" -V "$FW_VER" -L "$FW_LONG_VERSION" -H "$HEADER" -b "$OUT_BOOTCORE" -k "$OUT_KERNEL" -r "$ROOTFS"

SHA256_KERNEL=$(sha256 "$OUT_KERNEL")
SHA256_BOOTCORE=$(sha256 "$OUT_BOOTCORE")
SHA256_ROOTFS=$(sha256 "$ROOTFS")

SIZE_KERNEL=$(file_size "$OUT_KERNEL")
SIZE_BOOTCORE=$(file_size "$OUT_BOOTCORE")
SIZE_ROOTFS=$(file_size "$ROOTFS")

VER_8311=$(cat "$ROOT_DIR/etc/8311_version")

CONTROL_FILE="$REAL_OUT/control"
cat > "$CONTROL_FILE" <<CONTROL
$VER_8311

SIZE_KERNEL=$SIZE_KERNEL
SIZE_BOOTCORE=$SIZE_BOOTCORE
SIZE_ROOTFS=$SIZE_ROOTFS

SHA256_KERNEL=$SHA256_KERNEL
SHA256_BOOTCORE=$SHA256_BOOTCORE
SHA256_ROOTFS=$SHA256_ROOTFS
CONTROL

TAR_UPGRADE="$REAL_OUT/local-upgrade.tar"
echo -n "Creating local-upgrade TAR file..."
tar -c --sparse -f "$TAR_UPGRADE" -C "$REAL_OUT" -- "control" "kernel.bin" "bootcore.bin" "rootfs.img"
echo " Done"
rm -fv "$CONTROL_FILE" "$HEADER" "$KERNEL_BFW" "$BOOTCORE_BFW" "$ROOTFS_BFW"

echo "Firmware build $FW_LONG_VERSION complete."
