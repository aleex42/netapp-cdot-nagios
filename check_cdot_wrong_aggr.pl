#!/usr/bin/perl

# nagios: -epn

# --
# check_cdot_wrong_aggr - Check Aggregate for dedicated SnapMirror use
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
use Data::Dumper;

GetOptions(
    'hostname=s' => \my $Hostname,
    'username=s' => \my $Username,
    'password=s' => \my $Password,
    'warning=i'  => \my $Warning,
    'critical=i' => \my $Critical,
    'aggr=s'     => \my $Aggr,
    'perf'     => \my $perf,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;

my $message;
my $wrong_dp = 0;
my $wrong_rw = 0;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $iterator = NaElement->new("volume-get-iter");
my $tag_elem = NaElement->new("tag");
$iterator->child_add($tag_elem);

my $xi = new NaElement('desired-attributes');
$iterator->child_add($xi);
my $xi1 = new NaElement('volume-attributes');
$xi->child_add($xi1);
my $xi2 = new NaElement('volume-id-attributes');
$xi1->child_add($xi2);
$xi2->child_add_string('type');
$xi2->child_add_string('containing-aggregate-name');
my $xi3 = new NaElement('query');
$iterator->child_add($xi3);
my $xi4 = new NaElement('volume-attributes');
$xi3->child_add($xi4);
my $xi5 = new NaElement('query');
$iterator->child_add($xi5);

my $next = "";

while(defined($next)){
    unless($next eq ""){
        $tag_elem->set_content($next);    
    }

    $iterator->child_add_string("max-records", 100);
    my $output = $s->invoke_elem($iterator);

    if ($output->results_errno != 0) {
        my $r = $output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }

    my $vols = $output->child_get("attributes-list");

    if($vols){

        my @result = $vols->children_get();

        foreach my $vol (@result){

            my $id = $vol->child_get("volume-id-attributes");

            my $name = $id->child_get_string("name");
            my $aggr = $id->child_get_string("containing-aggregate-name");
            my $type = $id->child_get_string("type");

            if(($type eq "dp") && ($aggr =~ m/ata/)){
                $wrong_dp++;
            } 

            if(($type eq "rw") && ($aggr =~ m/snapmirror/)){
                $wrong_rw++;
            }
        }

    }

    $next = $output->child_get_string("next-tag");
}

if($wrong_dp != 0){

    print "$wrong_dp DP volume(s) wrong\n";
    exit 2;

} elsif($wrong_rw != 0){

    print "$wrong_rw nonDP volume(s) wrong\n";
    exit 2;
} else {
    print "OK - all volumes on right aggregate\n";
    exit 0;
}
