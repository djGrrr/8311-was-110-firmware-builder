#!/bin/bash
PACKAGES=(
	"busybox"
	"dropbear"
	"fping"
#	"gpiod-tools"
	"htop"
	"libc"
#	"libgpiod"
	"libncurses6"
#	"libsmartcols1"
	"libzstd"
	"lrzsz"
#	"lscpu"
	"nand-utils"
	"nano"
	"terminfo"
	"zoneinfo-[a-z]+"
	"zstd"
)
IPKS=$(find openwrt/bin/ | grep '\.ipk$' | sort -V)

find_ipks() {
	pcregrep "/($1)_[A-Za-z0-9._+-]+\.ipk" <<< "$IPKS"
}

for PACKAGE in "${PACKAGES[@]}"; do
	IPK=$(find_ipks "$PACKAGE")
	[ -n "$IPK" ] && cp -fv $IPK packages/
done
