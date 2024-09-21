#!/bin/sh
INTERFACES=$(ip -o li | egrep -o -- '^\d+: \S+[@:]' | awk -F '[ @:]+' '{print $2}' | egrep -- '^(eth|gem|pmapper|tcont|sw)' | egrep -v -- '(-omci|lct)$' | sort -V)
for DEV in $INTERFACES; do
    for DIR in ingress egress; do
        TC=$(tc filter show dev "$DEV" "$DIR")
        if [ -n "$TC" ]; then
            echo "--------------- tc filter show dev $DEV $DIR ---------------"
            echo "$TC"
            echo
            echo
        fi
    done
done
