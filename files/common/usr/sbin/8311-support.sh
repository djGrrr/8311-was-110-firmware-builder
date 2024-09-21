#!/bin/sh
echo "Generating support archive ..."
echo
OUT="/tmp/support.tar.gz"
TMPDIR=$(mktemp -d)

echo -n "Dumping FW ENVs ..."
fw_printenv | sort -V > "$TMPDIR/fwenvs.txt"
echo " done"

echo -n "Dumping pontop pages ..."
rm -f "/tmp/pontop.txt"
pontop -b > /dev/null
mv "/tmp/pontop.txt" "$TMPDIR/"
echo " done"

echo -n "Dumping OMCI MEs ..."
omci_pipe.sh md > "$TMPDIR/omci_pipe_md.txt"
omci_pipe.sh mda > "$TMPDIR/omci_pipe_mda.txt"
echo " done"

echo -n "Dumping VLAN tables ..."
8311-extvlan-decode.sh > "$TMPDIR/extvlan-tables.txt"
echo " done"

echo -n "Dumping TC Filters ..."
for DEV in $(ip -o li | egrep -o -- '^\d+: \S+[@:]' | awk -F '[ @:]+' '{print $2}' | egrep -- '^(eth|gem|pmapper|tcont|sw)' | egrep -v -- '(-omci|lct)$' | sort -V); do
	for DIR in ingress egress; do
		TC=$(tc filter show dev "$DEV" "$DIR")
		if [ -n "$TC" ]; then
			echo "--------------- tc filter show dev $DEV $DIR ---------------"
			echo "$TC"
			echo
			echo
		fi 
	done
done > "$TMPDIR/tc_filters.txt"
echo " done"

echo -n "Dumping System Log ..."
logread > "$TMPDIR/system_log.txt"
echo " done"

echo
echo -n "Writing support archive '$OUT' ..."
rm -f "$OUT"
tar -cz -f "$OUT" -C "$TMPDIR" -- fwenvs.txt omci_pipe_md.txt omci_pipe_mda.txt pontop.txt system_log.txt extvlan-tables.txt tc_filters.txt
rm -rf "$TMPDIR"

echo " done"

echo
echo "WARNING: This support archive contains potentially sensitive information. Do not share it publically"
