#!/bin/bash


I18N_DIR="$BASE_DIR/i18n"
PO_DIR="$I18N_DIR/po"
LMO_DIR="$I18N_DIR/lmo"
PO2LMO_SRC_DIR="$I18N_DIR/po2lmo"
OUTPUT_DIR="$ROOT_DIR/usr/lib/lua/luci/i18n"

echo "Compiling po2lmo..."
[ -d "$PO2LMO_SRC_DIR" ] || exit
rm -fv $LMO_DIR/*.lmo
make -C "$PO2LMO_SRC_DIR" clean
make -C "$PO2LMO_SRC_DIR"

if [ ! -f "$PO2LMO_SRC_DIR/src/po2lmo" ]; then
    echo "Compilation failed. Exiting."
    exit 1
fi

mkdir -p "$LMO_DIR"
mkdir -p "$OUTPUT_DIR"

echo "Compiling lmo..."
for po_file in "$PO_DIR"/*.po; do
    if [ -f "$po_file" ] && ! grep -Pq '\.en\.po$' <<< "$po_file"; then
        po_filename=$(basename "$po_file" .po)
        lmo_file="$LMO_DIR/$po_filename.lmo"
        echo "Compiling $po_file to $lmo_file"
        "$PO2LMO_SRC_DIR/src/po2lmo" "$po_file" "$lmo_file"
    fi
done

echo "Copy lmo to output directory..."
mkdir -pv "$OUTPUT_DIR"
cp -fv "$LMO_DIR"/*.lmo "$OUTPUT_DIR/"

echo "Success."
