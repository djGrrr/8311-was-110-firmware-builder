#!/bin/sh
[ -n "$2" ] && [ -f "$1" ] && perl -0777ne 'print pack(q{V*},unpack(q{N*},$_))' "$1" > "$2"
