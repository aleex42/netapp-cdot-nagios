# NetApp cDOT Nagios Monitoring Skripts

## About

Scripts for monitoring NetApp cDOT Clusters via NetApp Manageability SDK (Perl)

For older 7-Mode systems use my [7-Mode Scripts](https://github.com/aleex42/netapp-7mode-nagios)

## Plugins

Currently there are the following checks:

* check_cdot_aggr.pl: Aggregate Space Usage (also supports performance data)
* check_cdot_clusterconfig.sh: Same network configuration on all nodes
* check_cdot_clusterlinks.pl: HA and Cluster Interconnects
* check_cdot_diff_snapmirror.pl
* check_cdot_disk.pl: Disk Drive Status
* check_cdot_fcp.pl: FC Interface Errors
* check_cdot_global.pl: Global Cluster Health
* check_cdot_interfaces.pl: Interface Group Status and Interface Errors
* check_cdot_lun.pl: Lun Usage
* check_cdot_metrocluster_aggr.pl: Metrocluster Aggregate Status
* check_cdot_metrocluster_check.pl: Metrocluster Check
* check_cdot_metrocluster_config.pl: Metrocluster Configuration
* check_cdot_metrocluster_state.pl: Metrocluster Global Status
* check_cdot_multipath.pl: SAS Bus Multipathing
* check_cdot_quota.pl: Quota Usage
* check_cdot_rebuild.pl: Aggregate RAID Status
* check_cdot_recommendations.pl: some Best Practises
* check_cdot_snapmirror.pl: SnapMirror Health
* check_cdot_snapmirror_snapshots.pl: Old Snapmirror Snapshots
* check_cdot_snapshots.pl: Snapshot Age
* check_cdot_sparedisks.pl: Sparedisk Zeroed State and Ownership
* check_cdot_volume.pl: Volume Space and I-Node Usage (also supports performance data)
* check_cisco_nexus_ports.pl: Cisco Nexus Cluster-Switch Port Status

# Examples

For some examples have a look at my wiki: 
http://wiki.krogloth.de/index.php/NetApp_C-Mode/Monitoring


# Contact / Author

Alexander Krogloth
<git at krogloth.de>
<alexander.krogloth at noris.de> for the noris network AG.

See also the list of [contributors](https://github.com/aleex42/netapp-cdot-nagios/CONTRIBUTORS.md) who participated in this project.
