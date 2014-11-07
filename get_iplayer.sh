#!/bin/bash
lockfile=/var/shutdown_block/iplayer
if [ -e $lockfile ]; then
	exit
fi
touch $lockfile
# Remove any partial downloads, as there are problems resuming partial downloads
rm /media/media/iplayer/*default.partial* 2> /dev/null
# Pull new stuff from iplayer
/usr/bin/get-iplayer --pvr 2>>/tmp/get_iplayer.log
rm $lockfile
