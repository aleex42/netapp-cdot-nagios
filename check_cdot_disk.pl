#!/usr/bin/perl

# --
# check_cdot_disk - Check NetApp System Disk State
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
    print "$0: " . shift;
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $output = $s->invoke("storage-disk-get-iter");

if ($output->results_errno != 0) {
	my $r = $output->results_reason();
	print "UNKNOWN - $r\n";
	exit 3;
}

my $disks = $output->child_get("attributes-list");
my $disk_count = 0;
my @result = $disks->children_get();

my $failed_disk = 0;
my $disk_list;
my $diskstate;

foreach my $disk (@result){
	
	$disk_count++;

	my $owner = $disk->child_get("disk-ownership-info");

	$diskstate = $owner->child_get_string("is-failed");
	my $diskname = $disk->child_get_string("disk-name");

	if($diskstate eq "true"){
		$failed_disk++;
	        $disk_list .=  $diskname;
	}
	
}

if($failed_disk > 0){
        print "$failed_disk failed disk(s): $disk_list\n";
        exit 2;
} else {
        print "All $disk_count disks OK\n";
        exit 0;
}


