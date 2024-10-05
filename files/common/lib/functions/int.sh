#!/bin/sh
_lib_int() {
	return 0
}

int8() {
	int=$(($1 & 0xff))
	[ "$int" -gt $((0x80)) ] && echo $((int - 0x100)) || echo $int
}

uint8() {
	echo $(($1 & 0xff))
}

int16() {
	int=$(($1 & 0xffff))
	[ "$int" -ge $((0x8000)) ] && echo $((int - 0x10000)) || echo $int
}

uint16() {
	echo $(($1 & 0xffff))
}

int32() {
	local int=$(($1 & 0xffffffff))
	[ "$int" -ge $((0x80000000)) ] && echo $((int - 0x100000000)) || echo $int
}

uint32() {
	echo $(($1 & 0xffffffff))
}

int64() {
	echo $(($1))
}

uint64() {
	printf '%u\n' "$(int64 "$1")"
}
