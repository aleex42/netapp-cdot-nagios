#!/usr/bin/perl

# check_cdot_disks
# usage: ./check_cdot_disks hostname username password
# Alexander Krogloth <git at krogloth.de>

use lib "/usr/lib/netapp-manageability-sdk-5.1/lib/perl/NetApp";
use NaServer;
use NaElement;
use strict;
use warnings;

my $s = NaServer->new ($ARGV[0], 1, 3);

$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user($ARGV[1], $ARGV[2]);

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


