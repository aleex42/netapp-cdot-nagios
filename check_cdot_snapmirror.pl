#!/usr/bin/perl

# --
# check_cdot_snapmirror - Checks if all snapmirrors are healthy
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

my $output = $s->invoke("snapmirror-get-iter");

if ($output->results_errno != 0) {
	my $r = $output->results_reason();
	print "UNKNOWN - $r\n";
	exit 3;
}

my $snapmirror_failed = 0;
my $snapmirror_ok = 0;
my $failed_names;

my $snapmirrors = $output->child_get("attributes-list");
my @result = $snapmirrors->children_get();

foreach my $snap (@result){

	my $healthy = $snap->child_get_string("is-healthy");

	if($healthy eq "false"){

		my $name = $snap->child_get_string("destination-volume");

	        if($failed_names){
	                $failed_names .= ", " . $name;
	        } else {
	                $failed_names .= $name;
	        }

		$snapmirror_failed++;
	}
	$snapmirror_ok++;
}

if($snapmirror_failed > 0){
        print "CRITICAL: $snapmirror_failed snapmirror(s) failed - $snapmirror_ok snapmirror(s) ok\n$failed_names\n";
        exit 2;
} else {
	print "OK: $snapmirror_ok snapmirror(s) ok\n";
	exit 0;
}

