#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_storage_bridge - Check Storage Bridge state
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
use Data::Dumper;

GetOptions(
    'H|hostname=s' => \my $Hostname,
    'u|username=s' => \my $Username,
    'p|password=s' => \my $Password,
    'h|help'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

my @broken_bridge;

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

my $api = new NaElement('storage-bridge-get-iter');
my $tag_elem = NaElement->new("tag");
$api->child_add($tag_elem);

my $xi = new NaElement('desired-attributes');
$api->child_add($xi);

my $xi1 = new NaElement('storage-bridge-info');
$xi->child_add($xi1);

$xi1->child_add_string('name','<name>');
$xi1->child_add_string('status','<status>');

my $next = "";

while(defined($next)){
    unless($next eq ""){
        $tag_elem->set_content($next);
    }

    $api->child_add_string("max-records", 100);
    my $output = $s->invoke_elem($api);

    if ($output->results_errno != 0) {
        my $r = $output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }

    my $aggrs = $output->child_get("attributes-list");
    my @result = $aggrs->children_get();

    foreach my $bridge (@result){

        my $name = $bridge->child_get_string("name");
        my $status = $bridge->child_get_string("status");

        unless($status eq "ok"){
            push(@broken_bridge, $name);
        }
    }

    $next = $output->child_get_string("next-tag");

}

my $count = scalar(@broken_bridge);

if($count > 0){
    print "CRITICAL: $count bridge error(s):\n";
    print join(", ",@broken_bridge);
    print "\n";
    exit 2;
} else {
    print "OK: all bridge ok\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_storage_bridge - Check Storage Bridge

=head1 SYNOPSIS

check_cdot_storage_bridge.pl -H HOSTNAME -u USERNAME \
           -p PASSWORD 

=head1 DESCRIPTION

Checks the Storage Bridge Status of the NetApp System and warns
if anything is not 'ok'

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
2 if any bridge isn't ok
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
