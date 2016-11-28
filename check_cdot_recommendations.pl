#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_recommendation - Check cDOT Volume/SnapMirror Recommendations
# Copyright (C) 2013 noris network AG, http://www.noris.net/
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
use Getopt::Long;

GetOptions(
    'hostname=s' => \my $Hostname,
    'username=s' => \my $Username,
    'password=s' => \my $Password,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error( "$0: Error in command line arguments\n" );

sub Error {
    print "$0: ".$_[0]."\n";
    exit 2;
}
Error( 'Option --hostname needed!' ) unless $Hostname;
Error( 'Option --username needed!' ) unless $Username;
Error( 'Option --password needed!' ) unless $Password;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type( "HTTPS" );
$s->set_style( "LOGIN" );
$s->set_admin_user( $Username, $Password );

my $iterator = NaElement->new( "volume-get-iter" );
my $tag_elem = NaElement->new( "tag" );
$iterator->child_add( $tag_elem );

my $xi = new NaElement( 'desired-attributes' );
$iterator->child_add( $xi );
my $xi1 = new NaElement( 'volume-attributes' );
$xi->child_add( $xi1 );
my $xi2 = new NaElement( 'volume-id-attributes' );
$xi1->child_add( $xi2 );
my $xi3 = new NaElement( 'volume-space-attributes' );
$xi1->child_add( $xi3 );
my $xi13 = new NaElement( 'volume-qos-attributes' );
$xi1->child_add( $xi13 );
my $xi14 = new NaElement( 'volume-state-attributes' );
$xi1->child_add( $xi14 );
my $xi4 = new NaElement( 'volume-snapshot-attributes' );
$xi1->child_add( $xi4 );

my $next = "";
my @no_qos;
my @no_guarantee;
my @no_schedule = ();
my @no_failover;
my @snap_policy;

while(defined( $next )){
    unless ($next eq "") {
        $tag_elem->set_content( $next );
    }

    $iterator->child_add_string( "max-records", 100 );
    my $output = $s->invoke_elem( $iterator );

    if ($output->results_errno != 0) {
        my $r = $output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }

    my $volumes = $output->child_get( "attributes-list" );
    my @result = $volumes->children_get();

    foreach my $vol (@result) {

        my $snap_info = $vol->child_get( "volume-snapshot-attributes" );
        my $policy = $snap_info->child_get_string( "snapshot-policy" );
        my $vol_info = $vol->child_get( "volume-id-attributes" );
        my $vol_name = $vol_info->child_get_string( "name" );

        if ($policy) {
            if ($policy eq "default") {
                push( @snap_policy, $vol_name );
            }
        }

        my $vol_type = $vol_info->child_get_string( "type" );

        my $vol_state = $vol->child_get( "volume-state-attributes" );
        if ($vol_state) {

            my $state = $vol_state->child_get_string( "state" );

            if ($state && ($state eq "online")) {

                unless (($vol_name eq "vol0") || ($vol_name =~ m/_root$/) || ($vol_type eq "dp") || ($vol_name =~ m/^temp__/) || ($vol_name =~ m/^CC_snapprotect_SP/)) {

                    my $space = $vol->child_get( "volume-space-attributes" );
                    my $qos = $vol->child_get( "volume-qos-attributes" );
                    my $guarantee = $space->child_get_string( "space-guarantee" );

                    unless ($qos) {
                        push( @no_qos, $vol_name );
                    }

                    unless ($guarantee eq "none") {
                        push( @no_guarantee, $vol_name );
                    }
                }
            }
        }
    }
    $next = $output->child_get_string( "next-tag" );
}

my $snapmirror_iterator = NaElement->new( "snapmirror-get-iter" );
my $snapmirror_tag_elem = NaElement->new( "tag" );
$snapmirror_iterator->child_add( $snapmirror_tag_elem );

my $snapmirror_next = "";

while(defined( $snapmirror_next )){
    unless ($snapmirror_next eq "") {
        $snapmirror_tag_elem->set_content( $snapmirror_next );
    }

    $snapmirror_iterator->child_add_string( "max-records", 100 );
    my $snapmirror_output = $s->invoke_elem( $snapmirror_iterator );

    if ($snapmirror_output->results_errno != 0) {
        my $r = $snapmirror_output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }

    my $snapmirrors = $snapmirror_output->child_get( "attributes-list" );
    if ($snapmirrors) {
        my @snapmirror_result = $snapmirrors->children_get();

        foreach my $snap (@snapmirror_result) {
            my $dest_vol = $snap->child_get_string( "destination-volume" );
            my $schedule = $snap->child_get_string( "schedule" );

            if (($dest_vol) && ($schedule)) {
                unless (($schedule =~ m/^hourly/) || ($schedule =~ m/daily/) || ($schedule =~ m/^15min$/) || ($dest_vol =~ m/^CC_snapprotect_SP/)) {
                    push( @no_schedule, $dest_vol );
                }
            }
        }
    }
    $snapmirror_next = $snapmirror_output->child_get_string( "next-tag" );
}

my $lif_iterator = NaElement->new( "net-interface-get-iter" );
my $lif_tag_elem = NaElement->new( "tag" );
$lif_iterator->child_add( $lif_tag_elem );

my $lif_next = "";

while(defined( $lif_next )){
    unless ($lif_next eq "") {
        $lif_tag_elem->set_content( $lif_next );
    }

    $lif_iterator->child_add_string( "max-records", 100 );
    my $lif_output = $s->invoke_elem( $lif_iterator );

    if ($lif_output->results_errno != 0) {
        my $r = $lif_output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }

    my $lifs = $lif_output->child_get( "attributes-list" );
    my @lif_result = $lifs->children_get();

    foreach my $lif (@lif_result) {

        my $lif_name = $lif->child_get_string( "interface-name" );
        my $failover_group = $lif->child_get_string( "failover-group" );
        my $role = $lif->child_get_string( "role" );

        if (($failover_group) && ($failover_group eq "system-defined")) {
            if (($role eq "data") || ($role eq "cluster-mgmt")) {
                push( @no_failover, $lif_name );
            }
        }
    }
    $lif_next = $lif_output->child_get_string( "next-tag" );
}

my $qos_count = @no_qos;
my $guarantee_count = @no_guarantee;
my $schedule_count = @no_schedule;
my $failover_count = @no_failover;
my $policy_count = @snap_policy;

if (($qos_count != 0) || ($guarantee_count != 0) || ($schedule_count != 0) || ($failover_count != 0) || ($policy_count != 0)) {

    print "WARNING: Not all recommendations are applied:\n";

    if ($qos_count != 0) {
        print "Vol without QOS:\n";
        foreach(@no_qos) {
            print "-> ".$_."\n";
        }
        print "\n";
    }

    if ($guarantee_count != 0) {
        print "Vol with wrong space-guarantee:\n";
        foreach(@no_guarantee) {
            print "-> ".$_."\n";
        }
        print "\n";
    }

    if ($schedule_count != 0) {
        print "SnapMirror without schedule:\n";
        foreach(@no_schedule) {
            print "-> ".$_."\n";
        }
    }
    if ($failover_count != 0) {
        print "LIFs without failover-groups:\n";
        foreach(@no_failover) {
            print "-> ".$_."\n";
        }
    }
    if ($policy_count != 0) {
        print "Volumes with default snapshot policy:\n";
        foreach(@snap_policy) {
            print "-> ".$_."\n";
        }
    }
    exit 1;
} else {
    print "OK - All recommendations are applied\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_recommendations - Check cDOT Volume/SnapMirror recommendations

=head1 SYNOPSIS

check_cdot_recommendations.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD

=head1 DESCRIPTION

Checks if all Volumes do have a QOS-Policy and Space-Guarantee "none" - additional: all SnapMirrors should have a schedule

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
1 if something is not best practise
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
