#!/bin/sh

_lib_8311 2>/dev/null || . /lib/8311.sh

FIRMWARE_PATH="/tmp/upgrade/firmware.img"
FIRMWARE_OUT="/tmp/firmware.img"

UPG=false
RESET=true

_help() {
	printf -- 'Utility to handle automatic version string updates.\n\n'
	printf -- 'Usage: %s [options]\n\n' "$0"
	printf -- 'Options:\n'
	printf -- '-u -r --upgrade\tUpdate the image version variables.\n'
	printf -- '-n --no-reset\tUpdate the image version variables without performing an omcid restart.\n'

	exit "$1"
}

while [ $# -gt 0 ]; do
	case "$1" in
		-u|-r|--upgrade)
			UPG=true
		;;
		-n|--no-reset)
			RESET=false
		;;
		-h|--help)
			_help 0
		;;
		*)
			_help 1
		;;
	esac
	shift
done

_err() {
	echo "$1" >&2
	echo "secure_upgrade: $1" | to_console
	[ "$2" -ge 0 ] 2>/dev/null && exit "$2"
}

_info() {
	echo "$1"
	echo "secure_upgrade: $1" | to_console
}

FIRMWARE_PATH="/tmp/upgrade/firmware.img"
FW_MATCH=$(fwenv_get_8311 --base64 'fw_match')
FW_MATCH_NUM=$(fwenv_get_8311 'fw_match_num' '1')

[ -f "$FIRMWARE_PATH" ] || _err "Firmware upgrade file '$FIRMWARE_PATH' does not exist." 1
[ -n "$FW_MATCH" ] || _err "No firmware version match string set in 8311_fw_match fwenv." 1
[ "$FW_MATCH_NUM" -gt 0 ] 2>/dev/null || FW_MATCH_NUM=1

_info "Checking firmware image '$FIRMWARE_PATH' for string #$FW_MATCH_NUM matching '$FW_MATCH'"
MATCH=$(strings "$FIRMWARE_PATH" | pcre2grep --line-buffered -o1 -m "$FW_MATCH_NUM" -- "$FW_MATCH" | tail -n "+$FW_MATCH_NUM" | head -n1)
[ -n "$MATCH" ] || _err "No match found." 1

_info "Matching string found: $MATCH"

$UPG && {
	_info "Moving firmware file '$FIRMWARE_PATH' to '$FIRMWARE_OUT'"
	mv -fv "$FIRMWARE_PATH" "$FIRMWARE_OUT"

	_info "Setting new 8311_sw_ver fwenvs."
	fwenv_set_8311 'sw_verA' "$MATCH"
	fwenv_set_8311 'sw_verB' "$MATCH"

	$RESET && {
		_info "Restarting OMCId"
		/etc/init.d/omcid.sh restart
	}
}

exit 0
