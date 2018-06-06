#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_metrocluster_state - Check Metrocluster State
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

my $api = new NaElement('metrocluster-get');

my $xi = new NaElement('desired-attributes');
$api->child_add($xi);

my $xi1 = new NaElement('metrocluster-info');
$xi->child_add($xi1);

$xi1->child_add_string('configuration-type','<configuration-type>');
$xi1->child_add_string('local-configuration-state','<local-configuration-state>');
$xi1->child_add_string('local-mode','<local-mode>');
$xi1->child_add_string('local-periodic-check-enabled','<local-periodic-check-enabled>');
$xi1->child_add_string('remote-auso-failure-domain','<remote-auso-failure-domain>');
$xi1->child_add_string('remote-configuration-state','<remote-configuration-state>');
$xi1->child_add_string('remote-mode','<remote-mode>');
$xi1->child_add_string('remote-periodic-check-enabled','<remote-periodic-check-enabled>');

my $output = $s->invoke_elem($api);

if ($output->results_errno != 0) {
    my $r = $output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $config = $output->child_get("attributes");

my $info = $config->child_get("metrocluster-info");

my $local_config = $info->child_get_string("local-configuration-state");
my $local_mode = $info->child_get_string("local-mode");
my $local_check = $info->child_get_string("local-periodic-check-enabled");
my $remote_config = $info->child_get_string("remote-configuration-state");
my $remote_mode = $info->child_get_string("remote-mode");
my $remote_check = $info->child_get_string("remote-periodic-check-enabled");

my $message = "Local-Config: $local_config, Local-Mode: $local_mode, Local-Periodic-Check: $local_check, Remote-Config: $remote_config, Remote-Mode: $remote_mode, Remote-Periodic-Check: $remote_check\n";

unless(($local_config eq "configured") && ($local_mode eq "normal") && ($local_check eq "true") && ($remote_config eq "configured") && ($remote_mode eq "normal") && ($remote_check eq "true")){
    print "CRITICAL: $message";
    exit 2;
} else {
    print "OK: $message";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_metrocluster_state - Check Metrocluster State

=head1 SYNOPSIS

check_cdot_metrocluster_state.pl -H HOSTNAME -u USERNAME -p PASSWORD 

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
