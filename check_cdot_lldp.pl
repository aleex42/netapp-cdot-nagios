#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_lldp - Check node options
# Copyright (C) 2019 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use 5.10.0;
use strict;
use warnings;
use lib "/usr/lib/netapp-manageability-sdk/lib/perl/NetApp";
use NaServer;
use NaElement;
use Getopt::Long qw(:config no_ignore_case);

# ignore warning for experimental 'given'
no if ($] >= 5.018), 'warnings' => 'experimental';

GetOptions(
    'H|hostname=s' => \my $Hostname,
    'u|username=s' => \my $Username,
    'p|password=s' => \my $Password,
    'plugin=s'     => \my $Plugin,
    'h|help'       => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error( "$0: Error in command line arguments\n" );

sub Error {
    print "$0: ".$_[0]."\n";
    exit 2;
}
Error( 'Option --hostname needed!' ) unless $Hostname;
Error( 'Option --username needed!' ) unless $Username;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type( "HTTPS" );
$s->set_style( "LOGIN" );
$s->set_admin_user( $Username, $Password );

my $iterator = NaElement->new( "options-get-iter" );
my $tag_elem = NaElement->new( "tag" );

my $xi2 = new NaElement('query');
$iterator->child_add($xi2);

my $xi3 = new NaElement('option-info');
$xi2->child_add($xi3);

$xi3->child_add_string('name','lldp.enable');
$xi3->child_add_string('value','off');

$iterator->child_add_string( "max-records", 100 );
my $output = $s->invoke_elem( $iterator );

if ($output->results_errno != 0) {
    my $r = $output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $count = 0;

unless ($output->child_get_string("num-records") eq "0"){

    my $heads = $output->child_get( "attributes-list" );
    my @result = $heads->children_get();
    
    $count = scalar @result;

}

unless($count eq "0"){
    print "CRITICAL: lldp not enabled on $count nodes\n";
    exit 2;
} else {
    print "OK: lldp enabled on all nodes\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_lldp.pl - Checks Node LLDP

=head1 SYNOPSIS

check_cdot_lldp.pl -H HOSTNAME -u USERNAME -p PASSWORD

=head1 DESCRIPTION

Checks Node LLDP

=head1 OPTIONS

=over 4

=item -H | --hostname FQDN

The Hostname of the NetApp to monitor (Cluster or Node MGMT)

=item -u | --username USERNAME

The Login Username of the NetApp to check

=item -p | --password PASSWORD

The Login Password of the NetApp to check

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 if timeout occured
2 if Critical Threshold has been reached
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
