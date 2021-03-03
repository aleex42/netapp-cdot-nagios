#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_metrocluster_check.pl - NetApp MCC Metrocluster Check
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
    'exclude=s'  => \my @excludelistarray,
    'h|help'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
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

my $api = new NaElement('metrocluster-check-get-iter');

my $xi = new NaElement('desired-attributes');
$api->child_add($xi);

my $xi1 = new NaElement('metrocluster-check-info');
$xi->child_add($xi1);

$xi1->child_add_string('additional-info','<additional-info>');
$xi1->child_add_string('component','<component>');
$xi1->child_add_string('result','<result>');
$xi1->child_add_string('timestamp','<timestamp>');
$api->child_add_string('max-records','1000');

my $output = $s->invoke_elem($api);

if ($output->results_errno != 0) {
    my $r = $output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $status = $output->child_get("attributes-list");

my @errors;
my @components = $status->children_get();

foreach my $component (@components){

    my $name = $component->child_get_string("component");
    my $result = $component->child_get_string("result");

print $name . "\n";
   
    unless(grep/$name/, @excludelistarray){

        unless($result eq "ok"){
            my $info = $component->child_get_string("additional-info");

            push(@errors, { component => $name, result => $result, error => $info });
        }
    }
}

if (@errors) {
    print "CRITICAL: ";
    foreach my $error (@errors){
        print "$error->{component}: $error->{result}\n";
    }
    exit 2;
} else {
    print "OK: Metrocluster state ok\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_metrocluster_check - Check Metrocluster State

=head1 SYNOPSIS

check_cdot_metrocluster_check.pl.pl -H HOSTNAME -u USERNAME -p PASSWORD --exclude EXCLUDE

=head1 DESCRIPTION

Checks the Metrocluster Status of the NetApp System and warns
if anything is not 'ok'

=head1 OPTIONS

=over 4

=item -H | --hostname FQDN

The Hostname of the NetApp to monitor (Cluster or Node MGMT)

=item -u | --username USERNAME

The Login Username of the NetApp to monitor

=item -p | --password PASSWORD

The Login Password of the NetApp to monitor

=item --exclude EXCLUDE

Exclude single component(s): for example "lifs"

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 on Unknown Error
2 if any aggregat isn't ok
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
