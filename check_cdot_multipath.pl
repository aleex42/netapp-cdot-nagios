#!/usr/bin/perl

# --
# check_cdot_multipath - Check if all disks are multipathed (4 paths)
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use 5.10.0;
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
) or Error("check_cdot_aggr: Error in command line arguments\n");

sub Error {
    print "$0: " . shift( $_[0] ) . "\n";
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
	print "Unknown - $r\n";
	exit 3;
}

my $heads = $output->child_get("attributes-list");
my @result = $heads->children_get();

my @failed_disks;
foreach my $disk (@result){

	my $paths = $disk->child_get("disk-paths");
        my $path_count = $paths->children_get("disk-path-info");
	my $disk_name = $disk->child_get_string("disk-name");

	if ($path_count ne "4"){
		my @disk_name = split(/:/,$disk_name);
		push @failed_disks, $disk_name[1];

	}

}

if (@failed_disks) {
	print 'CRITICAL: disk(s) not multipath: ' . join( ', ', @failed_disks ) . "\n";
	exit 2;
} else {
	print "All disks multipath\n";
	exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_multipath - Check if all disks are multipathed (4 paths)

=head1 SYNOPSIS

check_cdot_multipath.pl --hostname HOSTNAME --username USERNAME \
    --password PASSWORD

=head1 DESCRIPTION

Checks if all Disks are multipathed (4 paths)

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

2 if one or more disks doesn't have 4 Paths
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stelios Gikas <sgikas at demokrit.de>
