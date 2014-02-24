#!/bin/bash

# --
# check_cdot_clusterconf - Check some Configurations on all nodes
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

HOSTNAME=$1
USERNAME=$2 

NODES=$(ssh $USERNAME@$HOSTNAME node show | awk '$0 ~ "entries were displayed" { print $1 }')

VLAN_DIFF=$(ssh admin@$HOSTNAME network port vlan show | awk '$1 ~ "a0a-" { count[$1]++ } END { for (x in count) if (count[x] < '$NODES') printf x ", "; print }')
FAILOVER_DIFF=$(ssh admin@$HOSTNAME network interface failover-groups show | awk 'BEGIN{ nodes='$NODES'; count=nodes } $1 ~ "failover" { if (nodes != count) { print group ", " }; count=0; group=substr($1, 0, length($0)-1) } $2 ~ "a0a-" {count++}')

if [ -n "$VLAN_DIFF" ] || [ -n "$FAILOVER_DIFF" ]; then {

        if [ -n "$VLAN_DIFF" ]; then
                echo "VLAN configuration is different: $VLAN_DIFF"
        fi

        if [ -n "$FAILOVER_DIFF" ]; then
                echo "Failover-Group configuration is different: $FAILOVER_DIFF"
        fi

} else {
        echo "Configuration is OK"
        exit 0
}; fi

# Authors
#
# Alexander Krogloth <git at krogloth.de>
# Micha Krause < micha at noris.net>
