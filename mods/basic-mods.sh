#!/bin/bash

LANG_OPTIONS=(
	"en 'English'"
	"zh_cn 'Chinese Simplified'"
	"ja 'Japanese'"
	# "fr 'French'"
)

if ls packages/basic/*.ipk &>/dev/null; then
	for IPK in packages/basic/*.ipk; do
		echo "Extracting '$(basename "$IPK")' to '$ROOT_DIR'."
		tar xfz "$IPK" -O -- "./data.tar.gz" | tar xvz -C "$ROOT_DIR/"
	done
fi

UCI_FW_RULES="$ROOT_DIR/etc/uci-defaults/26-firewall-rules"

UCI_FW_RULES_HEAD=$(grep -B99999999 '/usr/sbin/ptp4l' "$UCI_FW_RULES" | head -n -1)
UCI_FW_RULES_FOOT=$(grep -A99999999 '/usr/sbin/ptp4l' "$UCI_FW_RULES")

echo "$UCI_FW_RULES_HEAD" > "$UCI_FW_RULES"

cat >> "$UCI_FW_RULES" <<'HTTP_RULES'

if [ -f /usr/sbin/uhttpd ]; then
	uci batch << EOF
		add firewall rule
		set firewall.@rule[-1].name='Allow-HTTP'
		set firewall.@rule[-1].src='lan'
		set firewall.@rule[-1].proto='tcp'
		set firewall.@rule[-1].dest_port='80'
		set firewall.@rule[-1].target='ACCEPT'
EOF

	if [ -f /usr/sbin/px5g ]; then
		uci batch << EOF
			add firewall rule
			set firewall.@rule[-1].name='Allow-HTTPs'
			set firewall.@rule[-1].src='lan'
			set firewall.@rule[-1].proto='tcp'
			set firewall.@rule[-1].dest_port='443'
			set firewall.@rule[-1].target='ACCEPT'
EOF
    fi
fi

HTTP_RULES

echo "$UCI_FW_RULES_FOOT" >> "$UCI_FW_RULES"


sed -r 's#(\s+start \"\$@\")$#\1 \&#' -i "$ROOT_DIR/etc/init.d/dropbear"

INITTAB="$ROOT_DIR/etc/inittab"
sed -r 's/^(ttyLTQ0)/#\1/g' -i "$INITTAB"
echo "::askconsole:/bin/login" >> "$INITTAB"

LUA8311="$ROOT_DIR/usr/lib/lua/8311"
mkdir -pv "$LUA8311"
cat > "$LUA8311/version.lua" <<8311VER
module "8311.version"

variant = "${FW_VARIANT}"
version = "${FW_VERSION}"
revision = "${FW_REVISION}"
8311VER

rm -fv "$ROOT_DIR/etc/mibs/prx300_1U.ini.bk"

LUCI_MENUD_SYSTEM_JSON="$ROOT_DIR/usr/share/luci/menu.d/luci-mod-system.json"
echo "Patching '$LUCI_MENUD_SYSTEM_JSON' ..."
LUCI_MENUD_SYSTEM=$(jq 'delpaths([["admin/system/flash"], ["admin/system/crontab"], ["admin/system/startup"], ["admin/system/admin/dropbear"]])' "$LUCI_MENUD_SYSTEM_JSON")
echo "$LUCI_MENUD_SYSTEM" > "$LUCI_MENUD_SYSTEM_JSON"

LUCI_MENUD_STATUS_JSON="$ROOT_DIR/usr/share/luci/menu.d/luci-mod-status.json"
echo "Patching '$LUCI_MENUD_STATUS_JSON' ..."
LUCI_MENUD_STATUS=$(jq 'delpaths([["admin/status/iptables"], ["admin/status/processes"]])' "$LUCI_MENUD_STATUS_JSON")
echo "$LUCI_MENUD_STATUS" > "$LUCI_MENUD_STATUS_JSON"

RPCD_LUCI="$ROOT_DIR/usr/libexec/rpcd/luci"
echo "Patching '$RPCD_LUCI' ..."
sed -r 's#passwd %s >/dev/null 2>&1#passwd %s \&>/dev/null \&\& /usr/sbin/8311-persist-root-password.sh \&>/dev/null#' -i "$RPCD_LUCI"

LUCI_CONFIG="$ROOT_DIR/etc/config/luci"
echo "Patching '$LUCI_CONFIG' ..."
for lang_option in "${LANG_OPTIONS[@]}"; do
	sed -i "/config internal 'languages'/a\\
	option $lang_option" "$LUCI_CONFIG"
done

if [ "$KERNEL_VARIANT" = "bfw" ]; then
	rm -rfv "$ROOT_DIR/lib/modules" "$ROOT_DIR/lib/firmware"
	cp -va "$ROOT_BFW/lib/modules/." "$ROOT_DIR/lib/modules"
	cp -va "$ROOT_BFW/lib/firmware/." "$ROOT_DIR/lib/firmware"
fi

BFW_FILES=(
)

for bfw_file in "${BFW_FILES[@]}"; do
	cp -fv "${ROOT_BFW}/${bfw_file}" "${ROOT_DIR}/${bfw_file}"
done
