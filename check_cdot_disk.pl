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
my @result = $disks->children_get();

my $disk_count = 0;
my @disk_list;
foreach my $disk (@result) {
	$disk_count++;

	my $owner = $disk->child_get("disk-ownership-info");
    my $diskstate = $owner->child_get_string('is-failed');
    if ( $diskstate eq 'true' ) {
        push @disk_list, $disk->child_get_string('disk-name');
    }
}

if (@disk_list) {
    print @disk_list . ' failed disk(s): ' . join( ', ', @disk_list ) . "\n";
    exit 2;
}
else {
    print "All $disk_count disks OK\n";
    exit 0;
}



