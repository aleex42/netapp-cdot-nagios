#!/usr/bin/perl

# check_cdot_aggr
# usage: ./check_cdot_aggr hostname username password percent_warning percent_critical
# Alexander Krogloth <git at krogloth.de>

use lib "/usr/lib/netapp-manageability-sdk-5.1/lib/perl/NetApp";
use NaServer;
use NaElement;
use strict;
use warnings;

my $percent_warn = $ARGV[3];
my $percent_crit = $ARGV[4];

my $s = NaServer->new ($ARGV[0], 1, 3);

$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user($ARGV[1], $ARGV[2]);

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

		if($percent >= $percent_crit){
			$critical++;
		}

    if($percent >= $percent_warn){
			$warning++;
    }

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

