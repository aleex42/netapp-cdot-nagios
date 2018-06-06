#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_metrocluster_aggr - Check Metrocluster Aggregate state
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

my $api = new NaElement('metrocluster-check-aggregate-get-iter');
my $tag_elem = NaElement->new("tag");
$api->child_add($tag_elem);

my $xi = new NaElement('desired-attributes');
$api->child_add($xi);

my $xi1 = new NaElement('metrocluster-check-aggregate-info');
$xi->child_add($xi1);

$xi1->child_add_string('additional-info','<additional-info>');
$xi1->child_add_string('aggregate','<aggregate>');
$xi1->child_add_string('check','<check>');
$xi1->child_add_string('result','<result>');

my $next = "";

while(defined($next)){
    unless($next eq ""){
        $tag_elem->set_content($next);
    }

    $api->child_add_string("max-records", 100);
    my $output = $s->invoke_elem($api);

    if ($output->results_errno != 0) {
        my $r = $output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }

    my $aggrs = $output->child_get("attributes-list");
    my @result = $aggrs->children_get();

    foreach my $aggr (@result){

        my $aggr_name = $aggr->child_get_string("aggregate");
        my $check = $aggr->child_get_string("check");
        my $check_result = $aggr->child_get_string("result");

        unless($check_result eq "ok"){

            if($check eq "mirroring_status"){
                push(@mirroring_status, $aggr_name);
            } elsif($check eq "disk_pool_allocation"){
                push(@disk_pool_allocation, $aggr_name);
            } elsif($check eq "ownership_state"){
                push(@ownership_state, $aggr_name);
            }
        }
    }

    $next = $output->child_get_string("next-tag");
}


if($#mirroring_status > 0){
    print "CRITICAL: mirroring status:\n";
    print join(", ",@mirroring_status);
    print "\n";
    exit 2;
} elsif($#disk_pool_allocation >0){
    print "CRITICAL: disk pool allocation:\n";
    print join(", ",@disk_pool_allocation);
    print "\n";
    exit 2;
} elsif($#ownership_state > 0){
    print "CRITICAL: ownership state::\n";
    print join(", ",@ownership_state);
    print "\n";
    exit 2;
} else {
    print "OK: all aggregates mirrored\n";
    exit 0;
}


__END__

=encoding utf8

=head1 NAME

check_cdot_metrocluster_aggr - Check Metrocluster Aggregate

=head1 SYNOPSIS

check_cdot_aggr.pl -H HOSTNAME -u USERNAME \
           -p PASSWORD 

=head1 DESCRIPTION

Checks the Metrocluster Aggregate Status of the NetApp System and warns
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
2 if any aggregat isn't ok
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
