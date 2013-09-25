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

my $snapmirrors = $output->child_get("attributes-list");
my @result = $snapmirrors->children_get();

my @failed_names;
foreach my $snap (@result){

	my $healthy = $snap->child_get_string("is-healthy");
	if($healthy eq "false"){
	        push @failed_names, $snap->child_get_string("destination-volume");
		$snapmirror_failed++;
	}
	else {
		$snapmirror_ok++;
	}
}

if ($snapmirror_failed) {
	print <<_;
CRITICAL: $snapmirror_failed snapmirror(s) failed - $snapmirror_ok snapmirror(s) ok
${ \join( ', ', @failed_names ) }
_
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

Checks the Healthnes of the SnapMirror

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to monitor

=item --username USERNAME

The Login Username of the NetApp to monitor

=item --password PASSWORD

The Login Password of the NetApp to monitor

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

2 if there is an error in the SnapMirror
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stelios Gikas <sgikas at demokrit.de>
