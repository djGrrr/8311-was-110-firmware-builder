#!/bin/bash


I18N_DIR="$BASE_DIR/i18n"
PO_DIR="$I18N_DIR/po"
LMO_DIR="$I18N_DIR/lmo"
PO2LMO_SRC_DIR="$I18N_DIR/po2lmo"
OUTPUT_DIR="$ROOT_DIR/usr/lib/lua/luci/i18n"

rm -fv $LMO_DIR/*.lmo

mkdir -p "$LMO_DIR"
mkdir -p "$OUTPUT_DIR"

for po_file in "$PO_DIR"/*.po; do
    if [ -f "$po_file" ] && ! grep -Pq '\.en\.po$' <<< "$po_file"; then
        po_filename=$(basename "$po_file" .po)
        lmo_file="$LMO_DIR/$po_filename.lmo"
        echo "Compiling $po_file to $lmo_file"
        "$TOOLS_DIR/po2lmo.py" "$po_file" "$lmo_file"
    fi
done

echo "Copy lmo to output directory..."
mkdir -pv "$OUTPUT_DIR"
cp -fv "$LMO_DIR"/*.lmo "$OUTPUT_DIR/"

echo "Success."
