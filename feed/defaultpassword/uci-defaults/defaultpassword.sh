#!/bin/ash

# Copyright 2016 InvizBox Ltd
#
# Licensed under the InvizBox Shared License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        https://www.invizbox.com/lic/license.txt

PASSWORD=$(dd if=/dev/mtd2 bs=1 skip=65520 count=16)

if [ $(uci get wireless.ap.key) == "TOKENPASSWORD" ]; then
    /usr/bin/passwd root <<EOF
${PASSWORD}
${PASSWORD}
EOF
    uci set wireless.ap.key=${PASSWORD}
    uci commit wireless
fi
