#!/bin/sh

# Copyright (C) 2015 OpenWrt.org
# Copyright 2016 InvizBox Ltd
#
# Licensed under the InvizBox Shared License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        https://www.invizbox.com/lic/license.txt

# 0 yes blockdevice handles this - 1 no it is not there
echo $DEVPATH
blkdev=`dirname $DEVPATH`
basename=`basename $blkdev`
device=`basename $DEVPATH`
path=$DEVPATH

if [ $basename != "block" ] && [ -z "${device##sd*}" ] ; then
    islabel=`blkid /dev/$device | grep -q LABEL ; echo $?`
    if [ $islabel -eq 0 ] ; then
        mntpnt=`blkid /dev/$device |sed 's/.*LABEL="\(.*\)" UUID.*/\1/'`
    else
        mntpnt=$device
    fi
    case "$ACTION" in
        add)
            mkdir -p "/export/$mntpnt"
            # Set APM value for automatic spin down
            /sbin/hdparm -B 127 /dev/$device
            # Try to be gentle on solid state devices
            mount -o rw,noatime,discard /dev/$device "/export/$mntpnt"
        ;;
        remove)
            # Once the device is removed, the /dev entry disappear. We need mountpoint
            mountpoint=`mount |grep /dev/$device | sed 's/.* on \(.*\) type.*/\1/' | sed 's/\\\040/ /'`
            umount -l "$mountpoint"
        ;;
    esac
fi
