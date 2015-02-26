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

NODES=$(ssh $USERNAME@$HOSTNAME "node show" | awk '$0 ~ "entries were displayed" { print $1 }')

VLAN_DIFF=$(ssh $USERNAME@$HOSTNAME "network port vlan show -fields vlan-name" | awk '{ print $2 }' | grep ^a0a | sort | uniq -u)
FAILOVER_DIFF=$(ssh $USERNAME@$HOSTNAME "network interface failover-groups show -fields targets" | awk -F ',' 'NF != '$NODES' && $1 !~ "[0-9]_[0-9]" && $1 ~ "(failover_|([0-9]{1,3}.){4})" { print $0}')

if [ -n "$VLAN_DIFF" ] || [ -n "$FAILOVER_DIFF" ]; then {

        if [ -n "$VLAN_DIFF" ]; then
                echo "VLAN configuration is different: $VLAN_DIFF"
        fi

        if [ -n "$FAILOVER_DIFF" ]; then
                echo "Failover-Group configuration is different: $FAILOVER_DIFF"
        fi
				exit 2
} else {
        echo "Configuration is OK"
        exit 0
}; fi

# Authors
#
# Alexander Krogloth <git at krogloth.de>
# Micha Krause < micha at noris.net>
