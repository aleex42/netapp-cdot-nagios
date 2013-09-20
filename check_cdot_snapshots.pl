#!/usr/bin/perl

# --
# check_cdot_snapshots - Check if old Snapshots exists
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --

use lib "/usr/lib/netapp-manageability-sdk-5.1/lib/perl/NetApp";
use NaServer;
use NaElement;
use strict;
use warnings;
use Getopt::Long;

GetOptions(
    'hostname=s' => \my $Hostname,
    'username=s' => \my $Username,
    'password=s' => \my $Password,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . shift . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;

my $now = time;
my $old = 0;
my $old_snapshots;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $snap_output = $s->invoke("snapshot-get-iter");
my $snapshots = $snap_output->child_get("attributes-list");
my @snap_result = $snapshots->children_get();

foreach my $snap (@snap_result){

	my $snap_name = $snap->child_get_string("name");
	my $snap_time = $snap->child_get_string("access-time");

	my $vol_name = $snap->child_get_string("volume");

        my $age = $now - $snap_time;

        if($age >= 7776000){
		$old++;
                if($old_snapshots){
                	$old_snapshots .= ", $vol_name/$snap_name";
		} else {
			$old_snapshots = "$vol_name/$snap_name";
		}
	}

}

if($old ne "0"){
	print "$old snapshot(s) older than 90 days:\n";
	print "$old_snapshots\n";
	exit 1;
} else {
	print "No snapshots older than 90 days\n";
	exit 0;
}
