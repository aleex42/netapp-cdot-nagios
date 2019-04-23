#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_certificates - Check if all certificates are valid
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

# Warning: requires more than "readonly" permissions ...

use 5.10.0;
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

my $api = new NaElement('security-certificate-get-iter');
my $tag_elem = NaElement->new( "tag" );
$api->child_add( $tag_elem );

my $xi = new NaElement('desired-attributes');
$api->child_add($xi);

my $xi1 = new NaElement('certificate-info');
$xi->child_add($xi1);

$xi1->child_add_string('common-name','<common-name>');
$xi1->child_add_string('email-address','<email-address>');
$xi1->child_add_string('expiration-date','<expiration-date>');
$xi1->child_add_string('expire-days','<expire-days>');
$xi1->child_add_string('hash-function','<hash-function>');
$xi1->child_add_string('is-default','<is-default>');
$xi1->child_add_string('is-system-generated','<is-system-generated>');
$xi1->child_add_string('locality','<locality>');
$xi1->child_add_string('organization','<organization>');
$xi1->child_add_string('organization-unit','<organization-unit>');
$xi1->child_add_string('protocol','<protocol>');
$xi1->child_add_string('public-certificate','<public-certificate>');
$xi1->child_add_string('serial-number','<serial-number>');
$xi1->child_add_string('size','<size>');
$xi1->child_add_string('start-date','<start-date>');
$xi1->child_add_string('state','<state>');
$xi1->child_add_string('subtype','<subtype>');
$xi1->child_add_string('type','<type>');
$xi1->child_add_string('vserver','<vserver>');
$api->child_add_string('max-records','1000');

my @old_certs;

my $next = "";

while(defined($next)) {
    unless ($next eq "") {
        $tag_elem->set_content( $next );
    }

    $api->child_add_string( "max-records", 100 );
    my $output = $s->invoke_elem( $api );

    if ($output->results_errno != 0) {
        my $r = $output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }

    my $certs = $output->child_get( "attributes-list" );

    unless ($certs) {
        last;
    }

    my @result = $certs->children_get();

    foreach my $cert (@result) {

        my $ex_date = $cert->child_get_string("expiration-date");
        my $vserver = $cert->child_get_string("vserver");

        my $now = time;

        if($ex_date < $now) {

            push(@old_certs, $vserver);

        }

    }

    $next = $output->child_get_string( "next-tag" );

}

if (@old_certs) {
    print 'CRITICAL: certificates expired: '.join( ', ', @old_certs )."\n";
    exit 2;
} else {
    print "OK: certificates valid\n";
    exit 0;
}
