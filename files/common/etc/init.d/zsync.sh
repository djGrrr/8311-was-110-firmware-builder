#!/bin/sh /etc/rc.common

START=99

start() {
	echo "Sync all filesystems"
	sync
}
