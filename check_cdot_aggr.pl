#!/usr/bin/perl

# --
# check_cdot_aggr - Check Aggregate real Space Usage
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
    'warning=i'  => \my $Warning,
    'critical=i' => \my $Critical,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . shift( $_[0] ) . "\n";
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

my $message  = '';
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

        if ($message) {
            $message .= ", " . $aggr_name . " (" . $percent . "%)";
        }
        else {
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

__END__

=encoding utf8

=head1 NAME

check_cdot_aggr - Check Aggregate real Space Usage

=head1 SYNOPSIS

check_cdot_aggr.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD --warning PERCENT_WARNING \
           --critical PERCENT_CRITICAL

=head1 DESCRIPTION

Checks the Aggregate real Space Usage of the NetApp System and warns
if warning or critical Thresholds are reached

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to monitor

=item --username USERNAME

The Login Username of the NetApp to monitor

=item --password PASSWORD

The Login Password of the NetApp to monitor

=item --warning PERCENT_WARNING

The Warning threshold

=item --critical PERCENT_CRITICAL

The Critical threshold

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 on Unknown Error
2 if Critical Threshold has been reached
1 if Warning Threshold has been reached
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stelios Gikas <sgikas at demokrit.de>
