#!/usr/bin/perl

# check_cdot_multipath
# usage: ./check_cdot_multipath hostname username password
# Alexander Krogloth <git at krogloth.de>

use lib "/usr/lib/netapp-manageability-sdk-5.1/lib/perl/NetApp";
use NaServer;
use NaElement;
use strict;
use warnings;
use 5.10.0;

my $s = NaServer->new ($ARGV[0], 1, 3);

$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user($ARGV[1], $ARGV[2]);

my $output = $s->invoke("storage-disk-get-iter");

if ($output->results_errno != 0) {
	my $r = $output->results_reason();
	print "Unknown - $r\n";
	exit 3;
}

my $heads = $output->child_get("attributes-list");
my @result = $heads->children_get();

my $message;

foreach my $disk (@result){

	my $paths = $disk->child_get("disk-paths");
        my $path_count = $paths->children_get("disk-path-info");
	my $disk_name = $disk->child_get_string("disk-name");

	if ($path_count ne "4"){
		my @disk_name = split(/:/,$disk_name);
		$message .= " $disk_name[1]";

	}

}

if($message){
	print "CRITICAL: disk(s) not multipath: $message\n";
	exit 2;
} else {
	print "All disks multipath\n";
	exit 0;
}


