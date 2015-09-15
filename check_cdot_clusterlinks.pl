#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_clusterlinks.pl - Check cDOT HA-Interconnect and Cluster Links
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use strict;
use warnings;

use lib "/usr/lib/netapp-manageability-sdk-5.1/lib/perl/NetApp";
use NaServer;
use NaElement;
use Getopt::Long;

GetOptions(
    'hostname=s' => \my $Hostname,
    'username=s' => \my $Username,
    'password=s' => \my $Password,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

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

my $lif_api = new NaElement('net-port-get-iter');
$lif_api->child_add_string('max-records','1000000');

my $lif_output = $s->invoke_elem($lif_api);

if ($lif_output->results_errno != 0) {
    my $r = $lif_output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $lifs = $lif_output->child_get("attributes-list");
my @lif_result = $lifs->children_get();

my @failed_ports;

foreach my $lif (@lif_result){

    my $role = $lif->child_get_string("role");

    if($role eq "cluster"){

        my $link = $lif->child_get_string("link-status");
        my $name = $lif->child_get_string("port");
        my $node = $lif->child_get_string("node");

        if($link ne "up"){
            push(@failed_ports, "$node:$name");
        }
    }
}

my $node_api = new NaElement('cluster-node-get-iter');
my $node_output =$s->invoke_elem($node_api);

if ($node_output->results_errno != 0) {
    my $r = $node_output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $nodes = $node_output->child_get("attributes-list");
my @node_result = $nodes->children_get();
my $cf_api = new NaElement('cf-status');

my %failed_ics;

foreach my $node (@node_result){
    my $health = $node->child_get_string("is-node-healthy");

    if($health eq "true"){

        my $node_name = $node->child_get_string("node-name");
        my $cf_api = new NaElement('cf-status');
        $cf_api->child_add_string('node', $node_name);
        my $cf_output = $s->invoke_elem($cf_api);

        if ($cf_output->results_errno != 0) {
            my $r = $cf_output->results_reason();
            print "UNKNOWN: $r\n";
            exit 3;
        }

        my $link_status = $cf_output->child_get_string("interconnect-links");
        $link_status = (split(/[()]/, $link_status))[1];

        if(grep(/down/, $link_status)){
            $failed_ics{$node_name} = $link_status;
        }
    }
}

my $failed_count = @failed_ports;
my $ics_count = %failed_ics;

if(($failed_count != 0) || ( $ics_count != 0)){
    print "CRITICAL:";
    foreach (@failed_ports){
        print "$_ down, ";
    }
    foreach (keys %failed_ics){
        print $failed_ics{$_};
    }
    exit 2;
} else {
    print "OK: all clusterlinks up\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_clusterlinks - Check cDOT HA-Interconnect and Cluster Links

=head1 SYNOPSIS

check_cdot_clusterlinks.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD

=head1 DESCRIPTION

Checks if all HA-Interconnects and Cluster Links are up

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to monitor

=item --username USERNAME

The Login Username of the NetApp to monitor

=item --password PASSWORD

The Login Password of the NetApp to monitor

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 on Unknown Error
2 if any link is down
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
