#!/bin/bash

WORK_DIR=$(pwd)
I18N_DIR="$WORK_DIR/i18n"
PO_DIR="$I18N_DIR/po"
LMO_DIR="$I18N_DIR/lmo"
PO2LMO_SRC_DIR="$I18N_DIR/po2lmo"
OUTPUT_DIR="$WORK_DIR/files/basic/usr/lib/lua/luci/i18n"

echo "Compiling po2lmo..."
cd "$PO2LMO_SRC_DIR" || exit
make clean
make

if [ ! -f "$PO2LMO_SRC_DIR/src/po2lmo" ]; then
    echo "Compilation failed. Exiting."
    exit 1
fi

mkdir -p "$LMO_DIR"
mkdir -p "$OUTPUT_DIR"

echo "Compiling lmo..."
for po_file in "$PO_DIR"/*.po; do
    if [ -f "$po_file" ]; then
        po_filename=$(basename "$po_file" .po)
        lmo_file="$LMO_DIR/$po_filename.lmo"
        echo "Compiling $po_file to $lmo_file"
        "$PO2LMO_SRC_DIR/src/po2lmo" "$po_file" "$lmo_file"
    fi
done

echo "Copy lmo to output directory..."
cp -v "$LMO_DIR"/*.lmo "$OUTPUT_DIR/"

echo "Success."
