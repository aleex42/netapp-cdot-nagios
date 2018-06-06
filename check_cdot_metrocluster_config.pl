#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_metrocluster_config - Check Metrocluster Config Replication
# Copyright (C) 2018 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use strict;
use warnings;

use lib "/usr/lib/netapp-manageability-sdk/lib/perl/NetApp";
use NaServer;
use NaElement;
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;

GetOptions(
    'H|hostname=s' => \my $Hostname,
    'u|username=s' => \my $Username,
    'p|password=s' => \my $Password,
    'h|help'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

my @mirroring_status;
my @disk_pool_allocation;
my @ownership_state;

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;


my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $api = new NaElement('metrocluster-check-config-replication-get');

my $xi = new NaElement('desired-attributes');
$api->child_add($xi);

my $xi1 = new NaElement('metrocluster-check-config-replication-info');
$xi->child_add($xi1);

$xi1->child_add_string('cluster-recovery-steps','<cluster-recovery-steps>');
$xi1->child_add_string('cluster-streams','<cluster-streams>');
$xi1->child_add_string('heartbeat-recovery-steps','<heartbeat-recovery-steps>');
$xi1->child_add_string('is-enabled','<is-enabled>');
$xi1->child_add_string('is-running','<is-running>');
$xi1->child_add_string('last-heartbeat-received','<last-heartbeat-received>');
$xi1->child_add_string('last-heartbeat-sent','<last-heartbeat-sent>');
$xi1->child_add_string('recovery-steps','<recovery-steps>');
$xi1->child_add_string('remote-heartbeat','<remote-heartbeat>');
$xi1->child_add_string('storage-in-use','<storage-in-use>');
$xi1->child_add_string('storage-non-healthy-reason','<storage-non-healthy-reason>');
$xi1->child_add_string('storage-recovery-steps','<storage-recovery-steps>');
$xi1->child_add_string('storage-status','<storage-status>');
$xi1->child_add_string('vserver-recovery-steps','<vserver-recovery-steps>');
$xi1->child_add_string('vserver-streams','<vserver-streams>');

my $output = $s->invoke_elem($api);

if ($output->results_errno != 0) {
    my $r = $output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $config = $output->child_get("attributes");

my $replication_info = $config->child_get("metrocluster-check-config-replication-info");

my $storage_status = $replication_info->child_get_string("storage-status");
my $cluster_streams = $replication_info->child_get_string("cluster-streams");
my $enabled = $replication_info->child_get_string("is-enabled");
my $running = $replication_info->child_get_string("is-running");
my $heartbeat = $replication_info->child_get_string("remote-heartbeat");
my $vserver_streams = $replication_info->child_get_string("vserver-streams");

my $message = "Storage-Status: $storage_status, Cluster-Streams: $cluster_streams, Enabled: $enabled, Running: $running, Heartbeat: $heartbeat, Vserver-Streams: $vserver_streams\n"; 

unless(($storage_status eq "ok") && ($cluster_streams eq "ok") && ($enabled eq "true") && ($running eq "true") && ($heartbeat eq "ok") && ($vserver_streams eq "ok")){
    print "CRITICAL: $message";
    exit 2;
} else {
    print "OK: $message";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_metrocluster_config - Check Metrocluster Config

=head1 SYNOPSIS

check_cdot_metrocluster_config.pl -H HOSTNAME -u USERNAME -p PASSWORD 

=head1 DESCRIPTION

Checks the Metrocluster Config Replication Status of the NetApp System and warns
if anything is not 'ok'

=head1 OPTIONS

=over 4

=item -H | --hostname FQDN

The Hostname of the NetApp to monitor (Cluster or Node MGMT)

=item -u | --username USERNAME

The Login Username of the NetApp to monitor

=item -p | --password PASSWORD

The Login Password of the NetApp to monitor

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 on Unknown Error
2 if any config replication isn't ok
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
