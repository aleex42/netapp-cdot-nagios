#!/usr/bin/perl

# --
# check_cdot_snapshots - Check if old Snapshots exists
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
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

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $snap_output = $s->invoke("snapshot-get-iter");
my $snapshots = $snap_output->child_get("attributes-list");
my @snap_result = $snapshots->children_get();

my $now = time;
my @old_snapshots;
foreach my $snap (@snap_result){

	my $snap_time = $snap->child_get_string("access-time");
        my $age = $now - $snap_time;
        if($age >= 7776000){
		my $snap_name = $snap->child_get_string("name");
		my $vol_name  = $snap->child_get_string("volume");
                push @old_snapshots, "$vol_name/$snap_name";
	}
}

if (@old_snapshots) {
    print @old_snapshots . " snapshot(s) older than 90 days:\n";
    print "@old_snapshots\n";
    exit 1;
}
else {
    print "No snapshots are older than 90 days\n";
    exit 0;
}

