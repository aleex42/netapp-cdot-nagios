#!/usr/bin/perl

# --
# check_cdot_snapshots - Check if old Snapshots exists
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use lib "/usr/lib/netapp-manageability-sdk-5.1/lib/perl/NetApp";
use NaServer;
use NaElement;
use strict;
use warnings;
use Getopt::Long;

GetOptions(
    'hostname=s' => \my $Hostname,
    'username=s' => \my $Username,
    'password=s' => \my $Password,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $snap_output = $s->invoke("snapshot-get-iter");

if ($snap_output->results_errno != 0) {
    my $r = $snap_output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}


my $snapshots = $snap_output->child_get("attributes-list");
my @snap_result = $snapshots->children_get();

my $now = time;
my @old_snapshots;
foreach my $snap (@snap_result){

    my $snap_time = $snap->child_get_string("access-time");
    my $age = $now - $snap_time;
    if($age >= 7776000){
        my $snap_name = $snap->child_get_string("name");
        my $vol_name  = $snap->child_get_string("volume");
        push @old_snapshots, "$vol_name/$snap_name";
    }
}

if (@old_snapshots) {
    print @old_snapshots . " snapshot(s) older than 90 days:\n";
    print "@old_snapshots\n";
    exit 1;
}
else {
    print "No snapshots are older than 90 days\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_snapshots - Check if there are old Snapshots

=head1 SYNOPSIS

check_cdot_snapshots.pl --hostname HOSTNAME \
    --username USERNAME --password PASSWORD

=head1 DESCRIPTION

Checks if old ( > 90 days ) Snapshots exist

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

3 if timeout occured
1 if Warning Threshold (90 days) has been reached
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stelios Gikas <sgikas at demokrit.de>
