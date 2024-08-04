#!/bin/bash
COMMON_PACKAGES=(
	"busybox"
	"dropbear"
	"fping"
	"htop"
	"libc"
	"libncurses6"
	"libpcre2"
	"libzstd"
	"lrzsz"
	"mtr"
	"nand-utils"
	"nano"
	"terminfo"
	"zoneinfo-[a-z]+"
	"zstd"
)

BASIC_PACKAGES=(
	"liblucihttp"
	"liblucihttp0"
	"libmbedtls12"
	"libuhttpd-mbedtls"
	"libustream-mbedtls[0-9]+"
	"luci-base"
	"luci-lib-ip"
	"luci-lib-nixio"
	"luci-lib-px5g"
	"luci-mod-status"
	"luci-mod-system"
	"luci-theme-bootstrap"
#	"luci-theme-material"
#	"luci-theme-openwrt"
	"px5g-mbedtls"
	"rpcd-mod-luci"
	"uhttpd-mod-lua"
	"uhttpd-mod-ubus"
	"uhttpd"
)

BFW_PACKAGES=(
)

REMOVE_PACKAGES=(
	"luci-app-advanced-reboot"
	"luci-app-commands"
	"luci-app-firewall"
	"luci-app-opkg"
	"luci-mod-network"
	"luci-theme-openwrt"
)


IPKS=$(find openwrt/bin/ | grep '\.ipk$' | sort -V)

find_ipks() {
	pcregrep "/($1)_[A-Za-z0-9._+-]+\.ipk" <<< "$IPKS"
}

mkdir -p packages/common packages/basic packages/bfw packages/remove
rm -fv packages/common/*.ipk packages/basic/*.ipk packages/bfw/*.ipk packages/remove/*.list

for PACKAGE in "${COMMON_PACKAGES[@]}"; do
	IPK=$(find_ipks "$PACKAGE")
	[ -n "$IPK" ] && cp -fv $IPK packages/common/
done

for PACKAGE in "${BASIC_PACKAGES[@]}"; do
	IPK=$(find_ipks "$PACKAGE")
	[ -n "$IPK" ] && cp -fv $IPK packages/basic/
done

for PACKAGE in "${BFW_PACKAGES[@]}"; do
	IPK=$(find_ipks "$PACKAGE")
	[ -n "$IPK" ] && cp -fv $IPK packages/bfw/
done

for PACKAGE in "${REMOVE_PACKAGES[@]}"; do
	for IPK in $(find_ipks "$PACKAGE"); do
		LIST="packages/remove/$(basename "$IPK" ".ipk").list"
		echo "Creating file list '$LIST' from '$(basename "$IPK")'"
		tar xfz "$IPK" -O -- "./data.tar.gz" | tar tz | sed -r 's#^\./##g' > "$LIST"
	done
done
