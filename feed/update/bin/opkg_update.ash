#!/bin/ash

if [ $# -ne 0 ]
then
    opkg -f $1 update
else
    opkg update
fi
eval $(opkg list_installed | sed 's/ - .*/;/' | sed 's/^/opkg upgrade /')
