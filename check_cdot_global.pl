#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_global - Check powersupplies, fans, nvram status, temp or global health
# Copyright (C) 2013 noris network AG, http://www.noris.net/
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
Error( 'Option --plugin needed!' ) unless $Plugin;

if (( $Plugin ne 'power' )
    && ( $Plugin ne 'fan' )
    && ( $Plugin ne 'nvram' )
    && ( $Plugin ne 'temp' )
    && ( $Plugin ne 'health' ))
{
    Error( "Plugin $Plugin not known - possible Plugins: 'power', 'fan', 'nvram', 'temp', 'health'\n" );
}

my $failed_node;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type( "HTTPS" );
$s->set_style( "LOGIN" );
$s->set_admin_user( $Username, $Password );

my $iterator = NaElement->new( "system-node-get-iter" );
my $tag_elem = NaElement->new( "tag" );
$iterator->child_add( $tag_elem );

my $next = "";

my ($sum_failed_power, $sum_failed_nvram, $sum_failed_temp, $sum_failed_fan, $sum_failed_health) = 0;

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

    my $heads = $output->child_get( "attributes-list" );
    my @result = $heads->children_get();

    given ($Plugin) {
        when("power") {
            foreach my $head (@result) {
                my $failed_power_count = $head->child_get_string( "env-failed-power-supply-count" );
                my $node_name = $head->child_get_string( "node" );
                if ($failed_power_count) {
                    $sum_failed_power++;

                    if ($failed_node) {
                        $failed_node .= ", $node_name";
                    } else {
                        $failed_node .= $node_name;
                    }
                }
            }
        }

        when("fan") {
            foreach my $head (@result) {
                my $failed_fan_count = $head->child_get_string( "env-failed-fan-count" );
                my $node_name = $head->child_get_string( "node" );

                if ($failed_fan_count) {
                    $sum_failed_fan++;

                    if ($failed_node) {
                        $failed_node .= ", $node_name";
                    } else {
                        $failed_node .= $node_name;
                    }
                }
            }
        }

        when("nvram") {
            foreach my $head (@result) {
                my $nvram_status = $head->child_get_string( "nvram-battery-status" );
                my $node_name = $head->child_get_string( "node" );
                if ($head->child_get_string( "is-node-healthy" ) eq "true") {
                    $sum_failed_nvram++ if $nvram_status ne "battery_ok";

                    if ($failed_node) {
                        $failed_node .= ", $node_name";
                    } else {
                        $failed_node .= $node_name;
                    }
                }
            }
        }

        when("temp") {
            foreach my $head (@result) {
                my $temp_status = $head->child_get_string( "env-over-temperature" );
                my $node_name = $head->child_get_string( "node" );
                if ($head->child_get_string( "is-node-healthy" ) eq "true") {
                    $sum_failed_temp++ if $temp_status ne "false";

                    if ($failed_node) {
                        $failed_node .= ", $node_name";
                    } else {
                        $failed_node .= $node_name;
                    }
                }
            }
        }

        when("health") {
            foreach my $head (@result) {

                my $health_status = $head->child_get_string( "is-node-healthy" );
                my $node_name = $head->child_get_string( "node" );
                if ($health_status ne "true") {
                    $sum_failed_health++;

                    if ($failed_node) {
                        $failed_node .= ", $node_name";
                    } else {
                        $failed_node .= $node_name;
                    }
                }
            }
        }
    }
    $next = $output->child_get_string( "next-tag" );
}

given ($Plugin) {
    when("power") {
        if ($sum_failed_power) {
            print "CRITICAL: $sum_failed_power failed power supplie(s): $failed_node\n";
            exit 2;
        } else {
            print "OK: No failed power supplies\n";
            exit 0;
        }
    }
    when("fan") {
        if ($sum_failed_fan) {
            print "CRITICAL: $sum_failed_fan failed fan(s): $failed_node\n";
            exit 2;
        } else {
            print "OK: No failed fans\n";
            exit 0;
        }
    }
    when("nvram") {
        if ($sum_failed_nvram) {
            print "CRITICAL: $sum_failed_nvram failed nvram(s): $failed_node\n";
            exit 2;
        } else {
            print "OK: No failed nvram\n";
            exit 0;
        }
    }
    when("temp") {
        if ($sum_failed_temp) {
            print "CRITICAL: Temperature Overheating: $failed_node\n";
            exit 2;
        } else {
            print "OK: Temperature OK\n";
            exit 0;
        }
    }
    when("health") {
        if ($sum_failed_health) {
            print "CRITICAL: Health Status Critical: $failed_node\n";
            exit 2;
        } else {
            print "OK: Health Status OK\n";
            exit 0;
        }
    }
}

__END__

=encoding utf8

=head1 NAME

check_cdot_global.pl - Checks health status ( powersupplies, fans, ... )

=head1 SYNOPSIS

check_cdot_global.pl -H HOSTNAME -u USERNAME \
           -p PASSWORD --plugin PLUGIN

=head1 DESCRIPTION

Checks Health Status of:
  * Power Supplies
  * Fans
  * NvRam status
  * Temperatuter
  * Global Health

=head1 OPTIONS

=over 4

=item -H | --hostname FQDN

The Hostname of the NetApp to monitor (Cluster or Node MGMT)

=item -u | --username USERNAME

The Login Username of the NetApp to check

=item -p | --password PASSWORD

The Login Password of the NetApp to check

=item --plugin PLUGIN_NAME

possible Plugin Names are: 'power', 'fan', 'nvram', 'temp', 'health'

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
 Stelios Gikas <sgikas at demokrit.de>
