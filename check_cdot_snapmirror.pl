#!/usr/bin/perl

# --
# check_cdot_snapmirror - Checks SnapMirror Healthnes
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
    'lag=i'      => \my $LagOpt,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;
$LagOpt = 3600 * 28 unless $LagOpt; # 1 day 3 hours

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $snap_iterator = NaElement->new("snapmirror-get-iter");
my $tag_elem = NaElement->new("tag");
$snap_iterator->child_add($tag_elem);

my $next = "";
my $snapmirror_failed;
my $snapmirror_ok;
my %failed_names;

while(defined($next)){
	unless($next eq ""){
		$tag_elem->set_content($next);    
	}

	$snap_iterator->child_add_string("max-records", 100);
	my $snap_output = $s->invoke_elem($snap_iterator);

	if ($snap_output->results_errno != 0) {
		my $r = $snap_output->results_reason();
		print "UNKNOWN: $r\n";
		exit 3;
	}

	my $num_records = $snap_output->child_get_string("num-records");

	if($num_records eq 0){
		print "OK - No snapmirrors\n";
		exit 0;
	}

	my @snapmirrors = $snap_output->child_get("attributes-list")->children_get();

	foreach my $snap (@snapmirrors){

		my $status = $snap->child_get_string("relationship-status");
		my $healthy = $snap->child_get_string("is-healthy");
		my $lag = $snap->child_get_string("lag-time");
		my $dest_vol = $snap->child_get_string("destination-volume");
		my $current_transfer = $snap->child_get_string("current-transfer-type");

		if(($healthy eq "false") && (! $current_transfer)){
			$failed_names{$dest_vol} = [ $healthy, $lag ];
			$snapmirror_failed++;
		} elsif (($healthy eq "false") && ($current_transfer ne "intialize")){
			$failed_names{$dest_vol} = [ $healthy, $lag ];
			$snapmirror_failed++;    
		} else {
			$snapmirror_ok++;
		}

		if(defined($lag) && ($lag >= $LagOpt)){
			unless($failed_names{$dest_vol} || $status eq "transferring"){
				$failed_names{$dest_vol} = [ $healthy, $lag ];						
				$snapmirror_failed++;
			}
		} 
	}
	$next = $snap_output->child_get_string("next-tag");
}


if ($snapmirror_failed) {
	print "CRITICAL: $snapmirror_failed snapmirror(s) failed - $snapmirror_ok snapmirror(s) ok\n";
	printf ("%-*s%*s%*s\n", 50, "Name", 10, "Healthy", 10, "Delay");
	for my $vol ( keys %failed_names ) {
		my $health_lag = $failed_names{$vol};
		my @health_lag_value = @{ $health_lag };
		$health_lag_value[1] = "--- " unless $health_lag_value[1];
		printf ("%-*s%*s%*s\n", 50, $vol, 10, $health_lag_value[0], 10, $health_lag_value[1] . "s");
	}
	exit 2;
} else {
	print "OK: $snapmirror_ok snapmirror(s) ok\n";
	exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_snapmirror - Checks SnapMirror Healthnes

=head1 SYNOPSIS

check_cdot_snapmirror.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD --warning PERCENT_WARNING \
           --critical PERCENT_CRITICAL

=head1 DESCRIPTION

Checks the Healthnes of the SnapMirror and wheather every snapshot has a lag lower than one day

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to monitor

=item --username USERNAME

The Login Username of the NetApp to monitor

=item --password PASSWORD

The Login Password of the NetApp to monitor

=item --lag DELAY-SECONDS

Snapmirror delay in Seconds. Default 28h

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 if timeout occured
2 if there is an error in the SnapMirror
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stelios Gikas <sgikas at demokrit.de>
