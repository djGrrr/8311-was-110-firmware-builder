#!/bin/sh

filterhex() {
    sed -r 's/\s+//g' | grep -E '^([0-9a-f]{2})+$'
}

str2hex() {
	hexdump -v -e '1/1 "%02x"'
}

hex2str() {
	HEX=$(filterhex)
	[ -n "$HEX" ] && echo "$HEX" | sed 's/\([0-9A-F]\{2\}\)/\\\\\\x\1/gI' | xargs printf
}

str2printable() {
	hexdump -v -e '"%_p"'
}

hex2printable() {
	hex2str | str2printable
}
