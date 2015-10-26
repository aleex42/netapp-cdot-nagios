#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_diff_snapmirror - Checks Volumes without SnapMirror
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

my $snap_iterator = NaElement->new("snapmirror-get-destination-iter");
my $tag_elem = NaElement->new("tag");
$snap_iterator->child_add($tag_elem);

my $next = "";
my @snapmirror_sources;
my @missing_snapmirror;

while(defined($next)){
	unless($next eq ""){
		$tag_elem->set_content($next);    
	}

	$snap_iterator->child_add_string("max-records", 100);
	my $snap_output = $s->invoke_elem($snap_iterator);

	if ($snap_output->results_errno != 0) {
		my $r = $snap_output->results_reason();
		print "UNKNOWN: $r\n";
		exit 3;
	}

	my @snapmirrors = $snap_output->child_get("attributes-list")->children_get();

	foreach my $snap (@snapmirrors){
        my $source = $snap->child_get_string("source-location");
        push(@snapmirror_sources,$source);
	}
	$next = $snap_output->child_get_string("next-tag");
}

my $iterator = NaElement->new("volume-get-iter");
$tag_elem = NaElement->new("tag");
$iterator->child_add($tag_elem);

my $xi = new NaElement('desired-attributes');
$iterator->child_add($xi);
my $xi1 = new NaElement('volume-attributes');
$xi->child_add($xi1);
my $xi2 = new NaElement('volume-id-attributes');
$xi1->child_add($xi2);
$xi2->child_add_string('name','<name>');
my $xi4 = new NaElement('query');
$iterator->child_add($xi4);
my $xi5 = new NaElement('volume-attributes');
$xi4->child_add($xi5);
$next = "";

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

    my $volumes = $output->child_get("attributes-list");
    my @result = $volumes->children_get();

    foreach my $vol (@result){

        my $id = $vol->child_get("volume-id-attributes");

        my $vol_name = $id->child_get_string("name");

        unless($vol_name =~ m/vol0/){

            my $vserver = $id->child_get_string("owning-vserver-name");
            my $location = "$vserver:$vol_name";
    
            my $result = grep (/$location/,@snapmirror_sources);

            unless($result){
                push(@missing_snapmirror,$location);
            }
        }
    }
    $next = $output->child_get_string("next-tag");
}

if (@missing_snapmirror) {
    print @missing_snapmirror . " volume(s) without snapmirror:\n";
    print "@missing_snapmirror\n";
    exit 2;
}
else {
    print "All volumes are snapmirrored\n";
    exit 0;
}

