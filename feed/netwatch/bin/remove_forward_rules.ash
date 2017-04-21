#!/bin/ash

# Store rule numbers of FORWARD rules added via netwatch.lua
for line_num in $(iptables --line-numbers --list FORWARD | grep 'invizbox' | awk '{print $1}')
do
    LINES="$line_num $LINES"
done

# Delete lines by number (reverse)
for line in $LINES
do
    iptables -D FORWARD $line
done

unset LINES

for chain in OUTPUT PREROUTING POSTROUTING 
do
    [ -z "$chain" ] && break
    # Store rule numbers of nat/$chain rules added via netwatch.lua
    for line_num in $(iptables -t nat --line-numbers --list $chain | grep 'invizbox' | awk '{print $1}')
    do
        LINES="$line_num $LINES"
    done
    
    # Delete lines by number (reverse)
    for line in $LINES
    do
        iptables -t nat -D $chain $line
    done
    
    unset LINES
done
