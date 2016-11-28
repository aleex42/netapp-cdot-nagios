#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_sparedisk - Check NetApp System Spare Disks
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use strict;
use warnings;

use lib "/usr/lib/netapp-manageability-sdk/lib/perl/NetApp";
use NaServer;
use NaElement;
use Getopt::Long;

GetOptions(
    'hostname=s' => \my $Hostname,
    'username=s' => \my $Username,
    'password=s' => \my $Password,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error( "$0: Error in command line arguments\n" );

sub Error {
    print "$0: ".$_[0]."\n";
    exit 2;
}
Error( 'Option --hostname needed!' ) unless $Hostname;
Error( 'Option --username needed!' ) unless $Username;
Error( 'Option --password needed!' ) unless $Password;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type( "HTTPS" );
$s->set_style( "LOGIN" );
$s->set_admin_user( $Username, $Password );

my $iterator = NaElement->new( "storage-disk-get-iter" );
my $tag_elem = NaElement->new( "tag" );
$iterator->child_add( $tag_elem );

my $next = "";
my ($not_zeroed, $not_assigned);

while(defined( $next )){
    unless ($next eq "") {
        $tag_elem->set_content( $next );
    }

    $iterator->child_add_string( "max-records", 100 );
    my $output = $s->invoke_elem( $iterator );

    if ($output->results_errno != 0) {
        my $r = $output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }

    my $disks = $output->child_get( "attributes-list" );
    my @result = $disks->children_get();

    foreach my $disk (@result) {

        my $raid_info = $disk->child_get( "disk-raid-info" );
        my $type = $raid_info->child_get_string( "container-type" );

        if ($type eq "spare") {
            my $spare_info = $raid_info->child_get( "disk-spare-info" );
            my $zeroed = $spare_info->child_get_string( 'is-zeroed' );

            if ($zeroed eq "false") {
                $not_zeroed++;
            }
        } elsif ($type eq "unassigned") {
            $not_assigned++;
        }
    }
    $next = $output->child_get_string( "next-tag" );
}

if ($not_zeroed) {
    print "CRITICAL: $not_zeroed spare disk(s) not zeroed\n";
    exit 2;
} elsif ($not_assigned) {
    print "CRITICAL: $not_assigned disk(s) not assigned\n";
    exit 2;
} else {
    print "All spare disks zeroed\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_sparedisks - Checks Spare and Unassigned Disks

=head1 SYNOPSIS

check_cdot_sparedisks.pl --hostname HOSTNAME \
    --username USERNAME --password PASSWORD

=head1 DESCRIPTION

Checks if there are some nonzeroed or not assigned disks

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
2 if there are some nonzeroed disks
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>

