#!/bin/bash
if ls packages/remove/*.list &>/dev/null; then
	for LIST in packages/remove/*.list; do
		echo "Removing files from '$LIST'"
		FILES=$(cat "$LIST" | grep -v '/$')

		IFS=$'\n'
		for FILE in $(cat "$LIST" | grep -v '/$'); do
			rm -fv "$ROOT_DIR/$FILE" || true
		done

		for DIR in $(cat "$LIST" | grep '/$' | sort -r -V); do
			DIR="$ROOT_DIR/$DIR"
			CONTENTS=$(find "$DIR" -mindepth 1 -maxdepth 1 2>/dev/null) && [ -z "$CONTENTS" ] && rmdir -v "$DIR" || true
		done
		IFS=
	done
fi
