#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_nve - Check Volume Encryption
# Copyright (C) 2018 noris network AG, http://www.noris.net/
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
use Getopt::Long qw(:config no_ignore_case);

GetOptions(
    'H|hostname=s'          => \my $Hostname,
    'u|username=s'          => \my $Username,
    'p|password=s'          => \my $Password,
    'h|help'                => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: ".$_[0]."\n";
    exit 2;
}

Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type( "HTTPS" );
$s->set_style( "LOGIN" );
$s->set_admin_user( $Username, $Password );

my $iterator = NaElement->new( "volume-get-iter" );
my $tag_elem = NaElement->new( "tag" );
$iterator->child_add( $tag_elem );

my $xi = new NaElement( "desired-attributes" );
$iterator->child_add( $xi );
my $xi1 = new NaElement( "volume-attributes" );
$xi->child_add( $xi1 );
$xi1->child_add_string( "encrypt" );
my $xi2 = new NaElement( "volume-id-attributes" );
$xi1->child_add( $xi2 );
$xi2->child_add_string( "name", "<name>" );

my $next = "";

my @unencrypt;

while(defined($next)) {
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
	
	my $volumes = $output->child_get( "attributes-list" );

	unless ($volumes) {
	    last;
	}
	
	my @result = $volumes->children_get();

	foreach my $vol (@result) {

        my $vol_info = $vol->child_get("volume-id-attributes");
        my $vol_name = $vol_info->child_get_string( "name" );

        unless(($vol_name =~ m/_root$/) || ($vol_name =~ m/^MDV_CRS_/) || ($vol_name eq "vol0")){

            my $encrypt = $vol->child_get_string( "encrypt" );

            unless($encrypt eq "true"){
                push(@unencrypt, $vol_name);
            }
        }
	}
	$next = $output->child_get_string( "next-tag" );
}

if (scalar(@unencrypt) ) {
    print "CRITICAL: " . scalar(@unencrypt) . " volumes unencrypted:\n";
    print join (" ", @unencrypt);
    print "\n";
	exit 2;
} else {
    print "OK: all volumes encrypted\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_nve - Check Volume Encryption

=head1 SYNOPSIS

check_cdot_nve.pl -H HOSTNAME -u USERNAME -p PASSWORD

=head1 DESCRIPTION

Checks if all volumes are encrypted 

=head1 OPTIONS

=over 4

=item -H | --hostname FQDN

The Hostname of the NetApp to monitor (Cluster or Node MGMT)

=item -u | --username USERNAME

The Login Username of the NetApp to monitor

=item -p | --password PASSWORD

The Login Password of the NetApp to monitor

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 on Unknown Error
2 if Critical Threshold has been reached
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
