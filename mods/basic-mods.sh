#!/bin/bash

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
revision = "${FW_HASH}"
8311VER
