#!/usr/bin/perl

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

use lib "/usr/lib/netapp-manageability-sdk-5.1/lib/perl/NetApp";
use NaServer;
use NaElement;
use Getopt::Long;

GetOptions(
    'hostname=s' => \my $Hostname,
    'username=s' => \my $Username,
    'password=s' => \my $Password,
    'size-warning=i'  => \my $SizeWarning,
    'size-critical=i' => \my $SizeCritical,
    'inode-warning=i'  => \my $InodeWarning,
    'inode-critical=i' => \my $InodeCritical,
    'volume=s'   => \my $Volume,
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

my $api = new NaElement('volume-get-iter');
my $xi = new NaElement('desired-attributes');
$api->child_add($xi);
my $xi1 = new NaElement('volume-attributes');
$xi->child_add($xi1);
my $xi2 = new NaElement('volume-id-attributes');
$xi1->child_add($xi2);
my $xi3 = new NaElement('volume-space-attributes');
$xi1->child_add($xi3);
my $xi13 = new NaElement('volume-qos-attributes');
$xi1->child_add($xi13);
my $xi14 = new NaElement('volume-state-attributes');
$xi1->child_add($xi14);
$api->child_add_string('max-records','1000000');

my $output = $s->invoke_elem($api);

if ($output->results_errno != 0) {
    my $r = $output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $volumes = $output->child_get("attributes-list");
my @result = $volumes->children_get();

my @no_qos;
my @no_guarantee;
my @no_schedule = ();

foreach my $vol (@result){

    my $vol_info = $vol->child_get("volume-id-attributes");
    my $vol_name = $vol_info->child_get_string("name");
    my $vol_type = $vol_info->child_get_string("type");

    my $vol_state = $vol->child_get("volume-state-attributes");
    if($vol_state){

        my $state = $vol_state->child_get_string("state");

        if($state && ($state eq "online")){

            unless(($vol_name eq "vol0") || ($vol_name =~ m/_root$/) || ($vol_type eq "dp")){

                my $space = $vol->child_get("volume-space-attributes");
                my $qos = $vol->child_get("volume-qos-attributes");
                my $guarantee = $space->child_get_string("space-guarantee");

                unless($qos){
                    push(@no_qos, $vol_name);
                }

                unless($guarantee eq "none"){
                    push(@no_guarantee, $vol_name);
                }
            }
        }
    }
}

my $snapmirror_output = $s->invoke("snapmirror-get-iter");

if ($snapmirror_output->results_errno != 0) {
    my $r = $snapmirror_output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $snapmirrors = $snapmirror_output->child_get("attributes-list");
my @snapmirror_result = $snapmirrors->children_get();

foreach my $snap (@snapmirror_result){
    my $dest_vol = $snap->child_get_string("destination-volume");
    my $schedule = $snap->child_get_string("schedule");

    unless($schedule){
        push(@no_schedule, $dest_vol);
    }
}

my $qos_count = @no_qos;
my $guarantee_count = @no_guarantee;
my $schedule_count = @no_schedule;

if(($qos_count != 0) || ($guarantee_count != 0) || ($schedule_count != 0)){

    print "WARNING: not all recommendations are applied:\n";

    if($qos_count != 0){
        print "Vol without QOS:\n";
        foreach(@no_qos){
            print "-> " . $_ . "\n";
        }
        print "\n";
    }

    if($guarantee_count != 0){
        print "Vol with wrong space-guarantee:\n";
        foreach(@no_guarantee){
            print "-> " . $_ . "\n";
        }
        print "\n";
    }

    if($schedule_count != 0){
        print "SnapMirror without schedule:\n";
        foreach(@no_schedule){
            print "-> " . $_ . "\n";
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

check_cdot_recommendation - Check cDOT Volume/SnapMirror recommendations

=head1 SYNOPSIS

check_cdot_aggr.pl --hostname HOSTNAME --username USERNAME \
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
