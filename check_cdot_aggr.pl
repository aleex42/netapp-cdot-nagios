#!/usr/bin/perl

# --
# check_cdot_aggr - Check Aggregate real Space Usage
# Copyright (C) 2013 noris network AG, http://www.noris.net/
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
    'warning=i'  => \my $Warning,
    'critical=i' => \my $Critical,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . shift . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;
Error('Option --warning needed!')  unless $Warning;
Error('Option --critical needed!') unless $Critical;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $output = $s->invoke("aggr-get-iter");

if ($output->results_errno != 0) {
	my $r = $output->results_reason();
	print "UNKNOWN - $r\n";
	exit 3;
}

my $message;
my $critical = 0;
my $warning = 0;

my $aggrs = $output->child_get("attributes-list");
my @result = $aggrs->children_get();

foreach my $aggr (@result){

	my $aggr_name = $aggr->child_get_string("aggregate-name");

	if($aggr_name !~ /^aggr0/){
		
		my $space = $aggr->child_get("aggr-space-attributes");
		my $percent = $space->child_get_int("percent-used-capacity");

        $critical++ if $percent >= $Critical;
        $warning++  if $percent >= $Warning;


    if($message){
			$message .= ", " . $aggr_name . " (" . $percent . "%)";
		} else {
			$message .= $aggr_name . " (" . $percent . "%)";
		}
	}
}

if($critical > 0){
        print "CRITICAL: " . $message . "\n";
        exit 2;
} elsif($warning > 0){
        print "WARNING: " . $message . "\n";
        exit 1;
} else {
	print "OK: " . $message . "\n";
	exit 0;
}

