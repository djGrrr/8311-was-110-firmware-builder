#!/bin/sh
_help() {
    printf -- 'Tool for creating new WAS-110 local upgrade images\n\n'
    printf -- 'Usage: %s [options]\n\n' "$0"
    printf -- 'Options:\n'
    printf -- '-i --image <filename>\t\tSpecify local upgrade image file to create (required).\n'
    printf -- '-H --header <filename>\t\tSpecify filename of image header to base image off of (default: header.bin).\n'
    printf -- '-b --bootcore <filename>\tSpecify filename of bootcore image to place in created image (default: bootcore.bin).\n'
    printf -- '-k --kernel <filename>\t\tSpecify filename of kernel image to place in created image (default: kernel.bin).\n'
    printf -- '-r --rootfs <filename>\t\tSpecify filename of rootfs image to place in created image (default: rootfs.img).\n'
	printf -- '-V --image-version <version>\tSpecify version string to set on created image (14 characters max).\n'
    printf -- '-h --help\t\t\tThis help text\n'
}

OUT=
HEADER="header.bin"
BOOTCORE="bootcore.bin"
KERNEL="kernel.bin"
ROOTFS="rootfs.img"
VERSION=

while [ $# -gt 0 ]; do
	case "$1" in
		-i|--image)
			OUT="$2"
			shift
		;;
		-H|--header)
			HEADER="$2"
			shift
		;;
		-b|--bootcore)
			BOOTCORE="$2"
			shift
		;;
		-k|--kernel)
			KERNEL="$2"
			shift
		;;
		-r|--rootfs)
			ROOTFS="$2"
			shift
		;;
		-V|--image-version)
			VERSION="$2"
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

[ -n "$OUT" ] || _err "Error: Image file to create must be specified."
[ -n "$HEADER" ] || _err "Error: header file must be specified."
[ -f "$HEADER" ] || _err "Error: header file '$HEADER' not found."
[ -n "$BOOTCORE" ] || _err "Error: bootcore file must be specified."
[ -f "$BOOTCORE" ] || _err "Error: header file '$BOOTCORE' not found."
[ -n "$KERNEL" ] || _err "Error: kernel file must be specified."
[ -f "$KERNEL" ] || _err "Error: header file '$KERNEL' not found."
[ -n "$ROOTFS" ] || _err "Error: rootfs file must be specified."
[ -f "$ROOTFS" ] || _err "Error: header file '$ROOTFS' not found."

NUM=0
FILE_OFFSET=$((0x100))
LEN_HDR=$((0xD00))
DATA_OFFSET=$LEN_HDR
VERSION_OFFSET=$((0x30))

add_image() {
	IMAGE="$1"
	FILE="${2:-$1}"

	NAME_OFFSET=$((FILE_OFFSET + NUM * 48))
	SIZE_OFFSET=$((NAME_OFFSET + 32))
	if [ ! -f "$FILE" ]; then
		echo "File '$FILE' for image '$IMAGE' does not exist" >&2
		exit 1
	fi

	SIZE=$(stat -c "%s" "$FILE")

	echo "Adding image #$NUM ($IMAGE) from '$FILE' ($SIZE bytes)"
	{ echo -n "$IMAGE"; cat /dev/zero; } | dd of="$OUT" seek="$NAME_OFFSET" bs=1 count=32 conv=notrunc 2>/dev/null
	{ echo -n "$SIZE"; cat /dev/zero; } | dd of="$OUT" seek="$SIZE_OFFSET" bs=1 count=16 conv=notrunc 2>/dev/null

	cat "$FILE" >> "$OUT"

	DATA_OFFSET=$((DATA_OFFSET + SIZE))
	NUM=$((NUM + 1))
}

echo "Creating new image '$OUT' from header file '$HEADER'"
head -c "$LEN_HDR" "$HEADER" > "$OUT"

if [ -n "$VERSION" ]; then
	echo "Setting image version string to '$VERSION'"
	{ echo -n "$VERSION"; cat /dev/zero; } | dd of="$OUT" seek="$VERSION_OFFSET" bs=1 count=14 conv=notrunc 2>/dev/null
fi

add_image "bootcore.bin" "$BOOTCORE"
add_image "kernel.bin" "$KERNEL"
add_image "rootfs.img" "$ROOTFS"

