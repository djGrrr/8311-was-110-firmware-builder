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

[ -d "$ROOT_DIR/ptrom" ] && FW_VARIANT="bfw" || FW_VARIANT="basic"


. mods/common-mods.sh

. mods/binary-mods.sh

. "mods/${FW_VARIANT}-mods.sh"


OUT_BOOTCORE=$(realpath "$OUT_DIR/bootcore.bin")
[ "$BOOTCORE" = "$OUT_BOOTCORE" ] || cp -fv "$BOOTCORE" "$OUT_BOOTCORE"
OUT_KERNEL=$(realpath "$OUT_DIR/kernel.bin")
[ "$KERNEL" = "$OUT_KERNEL" ] || cp -fv "$KERNEL" "$OUT_KERNEL"

mksquashfs "$ROOT_DIR" "$ROOTFS" -all-root -noappend -comp xz -b 256K || _err "Error creating new rootfs image"
[ -n "$HEADER" ] && [ -f "$HEADER" ] && ./create.sh -i "$IMG_OUT" -H "$HEADER" -b "$BOOTCORE" -k "$KERNEL" -r "$ROOTFS"
