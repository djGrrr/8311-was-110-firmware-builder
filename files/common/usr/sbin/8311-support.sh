#!/bin/sh
echo "Generating support archive ..."
echo
OUT="/tmp/support.tar.gz"
TMPDIR=$(mktemp -d)
OUTDIR="$TMPDIR/support"

mkdir -p "$OUTDIR"

echo -n "Dumping FW ENVs ..."
fw_printenv | sort -V > "$OUTDIR/fwenvs.txt"
echo " done"

echo -n "Dumping pontop pages ..."
rm -f "/tmp/pontop.txt"
pontop -b > /dev/null
mv "/tmp/pontop.txt" "$OUTDIR/"
echo " done"

echo -n "Dumping OMCI MEs ..."
omci_pipe.sh md > "$OUTDIR/omci_pipe_md.txt"
omci_pipe.sh mda > "$OUTDIR/omci_pipe_mda.txt"
echo " done"

echo -n "Dumping VLAN tables ..."
8311-extvlan-decode.sh -t > "$OUTDIR/extvlan-tables.txt" && {
	printf "\n\n"
	8311-extvlan-decode.sh
} >> "$OUTDIR/extvlan-tables.txt"
echo " done"

echo -n "Dumping TC Filters ..."
8311-tc-filter-dump.sh > "$OUTDIR/tc_filters.txt"
echo " done"

echo -n "Dumping System Log ..."
logread > "$OUTDIR/system_log.txt"
echo " done"

echo
echo -n "Writing support archive '$OUT' ..."
rm -f "$OUT"
tar -cz -f "$OUT" -C "$TMPDIR" -- support
rm -rf "$TMPDIR"

echo " done"

echo
echo "WARNING: This support archive contains potentially sensitive information. Do not share it publically"
