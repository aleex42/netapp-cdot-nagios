#!/usr/bin/perl

# --
# check_cdot_global - Check powersupplys, fans, nvram status, temp or global health
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
    'plugin=s'   => \my $Plugin,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --plugin needed!')   unless $Plugin;

if (   ( $Plugin ne 'power' )
    && ( $Plugin ne 'fan' )
    && ( $Plugin ne 'nvram' )
    && ( $Plugin ne 'temp' )
    && ( $Plugin ne 'health' ) )
{
	Error("Plugin $Plugin not known - possible Plugins: 'power', 'fan', 'nvram', 'temp', 'health'\n");
}

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $output = $s->invoke("system-node-get-iter");

my $heads = $output->child_get("attributes-list");
my @result = $heads->children_get();
given ($Plugin) {
    when("power"){
        my $sum_failed_power = 0;
        foreach my $head (@result){
            my $failed_power_count = $head->child_get_string("env-failed-power-supply-count");
            $sum_failed_power+ if $failed_power_count;
        }
        if ($sum_failed_power) {
            print "$sum_failed_power failed power supply(s)\n";
            exit 2;
        } else {
            print "No failed power supplys\n";
            exit 0;
        }
    }

    when("fan"){
        my $sum_failed_fan = 0;
        foreach my $head (@result){
            my $failed_fan_count = $head->child_get_string("env-failed-fan-count");
            $sum_failed_fan++ if $failed_fan_count;
        }
        if ($sum_failed_fan) {
            print "$sum_failed_fan failed fan(s)\n";
            exit 2;
        } else {
            print "No failed fans\n";
            exit 0;
        }
    }

    when("nvram"){
        my $sum_failed_nvram = 0;
        foreach my $head (@result){
            my $nvram_status = $head->child_get_string("nvram-battery-status");
            $sum_failed_nvram++ if $nvram_status ne "battery_ok";
        }
        if ($sum_failed_nvram) {
            print "$sum_failed_nvram failed nvram(s)\n";
            exit 2;
        } else {
            print "No failed nvram\n";
            exit 0;
        }
    }

    when("temp"){
        my $sum_failed_temp = 0;
        foreach my $head (@result){
            my $temp_status = $head->child_get_string("env-over-temperature");
            $sum_failed_temp++ if $temp_status ne "false";
        }
        if ($sum_failed_temp) {
            print "Temperature Overheating\n";
            exit 2;
        } else {
            print "Temperature OK\n";
            exit 0;
        }
    }

    when("health"){
        my $sum_failed_health = 0;
        foreach my $head (@result){
            my $health_status = $head->child_get_string("is-node-healthy");
            $sum_failed_health++ if $health_status ne "true";
        }
        if ($sum_failed_health){
            print "Health Status Critical\n";
            exit 2;
        } else {
            print "Health Status OK\n";
            exit 0;
        }
    }
}

__END__

=encoding utf8

=head1 NAME

check_cdot_global.pl - Checks health status ( powersupplys, fans, ... )

=head1 SYNOPSIS

check_cdot_global --hostname HOSTNAME --username USERNAME \
           --password PASSWORD --plugin fan

=head1 DESCRIPTION

Checks Health Status of:
  * Power Supplys
  * Fans
  * NvRam status
  * Temperatuter
  * Global Health

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to check

=item --username USERNAME

The Login Username of the NetApp to check

=item --password PASSWORD

The Login Password of the NetApp to check

=item --plugin PLUGIN_NAME

possible Plugin Names are: 'power', 'fan', 'nvram', 'temp', 'health'

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

2 if Critical Threshold has been reached
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stelios Gikas <sgikas at demokrit.de>
