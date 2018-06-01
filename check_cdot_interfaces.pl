#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_interfaces.pl - Check cDOT Interface Groups Status
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use 5.6.1;
use strict;
use warnings;

use lib "/usr/lib/netapp-manageability-sdk/lib/perl/NetApp";
use NaServer;
use NaElement;
use Getopt::Long;

use Data::Dumper;

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

my @nodes;
my @failed_ports;
my %ifgrps;

my $node_iterator = NaElement->new( "system-node-get-iter" );

$node_iterator->child_add_string( "max-records", 10 );
my $node_output = $s->invoke_elem( $node_iterator );

if ($node_output->results_errno != 0) {
    my $r = $node_output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $heads = $node_output->child_get( "attributes-list" );
my @result = $heads->children_get();

foreach my $head (@result) {
    my $node_name = $head->child_get_string( "node" );

    my $ifgrp_iterator = NaElement->new( "net-port-ifgrp-get" );

    $ifgrp_iterator->child_add_string( "node", $node_name );
    $ifgrp_iterator->child_add_string( "ifgrp-name", "a0a" );
    my $ifgrp_output = $s->invoke_elem( $ifgrp_iterator );

    if ($ifgrp_output->results_errno != 0) {
        $ifgrp_iterator = NaElement->new( "net-port-ifgrp-get" );
        $ifgrp_iterator->child_add_string( "node", $node_name );
        $ifgrp_iterator->child_add_string( "ifgrp-name", "a0b" );
        $ifgrp_output = $s->invoke_elem( $ifgrp_iterator );

        if ($ifgrp_output->results_errno != 0) {
          my $r = $ifgrp_output->results_reason();
        	print "UNKNOWN: $r\n";
        	exit 3;
        }
    }

    my $ifgrps = $ifgrp_output->child_get( "attributes" );
    my $ifgrp_infos = $ifgrps->child_get( "net-ifgrp-info" );

    my $ifgrp_name = $ifgrp_infos->child_get_string( "ifgrp-name" );

    my $ports_foo = $ifgrp_infos->child_get( "ports" );
    my @ports = $ports_foo->children_get();

    my @ifgrp_ports;

    foreach my $port (@ports) {
        my %foo = %{$port};
        push( @ifgrp_ports, $foo{content} );
    }

    $ifgrps{$node_name} = \@ifgrp_ports;
}

my %failed_ports;

my $iterator = NaElement->new( "net-port-get-iter" );
my $tag_elem = NaElement->new( "tag" );
$iterator->child_add( $tag_elem );

my $next = "";

while(defined( $next )){
    unless ($next eq "") {
        $tag_elem->set_content( $next );
    }

    $iterator->child_add_string( "max-records", 100 );
    my $lif_output = $s->invoke_elem( $iterator );

    if ($lif_output->results_errno != 0) {
        my $r = $lif_output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }

    my $lifs = $lif_output->child_get( "attributes-list" );

    if($lifs) {

        my @lif_result = $lifs->children_get();
    
        foreach my $lif (@lif_result) {
  
            my $node = $lif->child_get_string( "node" );
            my $name = $lif->child_get_string( "port" );
            my $state = $lif->child_get_string( "link-status" );
  
            if($state ne "up") {
                push( @{$failed_ports{$node}}, $name);
            }
        }
    }

    $next = $lif_output->child_get_string( "next-tag" );
}

foreach my $node (keys %failed_ports) {

    foreach my $port (@{$failed_ports{$node}}) {

        if (grep(/$port/, @{$ifgrps{$node}})) {

            push( @failed_ports, "$node:$port" );
        }
    }
}

my @nics;
my $stats_output;
my @nic_errors;

my $stats = $s->invoke( "perf-object-instance-list-info-iter", "objectname", "nic_common" );

my $nics = $stats->child_get( "attributes-list" );

if($nics) {

    my @result = $nics->children_get();

    foreach my $interface (@result) {
        my $uuid = $interface->child_get_string( "uuid" );
        push(@nics, $uuid);
    }

    my $api = new NaElement( "perf-object-get-instances" );
    my $xi = new NaElement( "counters" );
    $api->child_add( $xi );
    $xi->child_add_string( "counter", "rx_crc_errors" );

    my $xi1 = new NaElement( "instance-uuids" );
    $api->child_add( $xi1 );

    foreach my $nic_uuid (@nics) {
        $xi1->child_add_string( "instance-uuid", $nic_uuid );
    }

    $api->child_add_string("objectname", "nic_common" );

    $stats_output = $s->invoke_elem( $api );

    my $instances = $stats_output->child_get( "instances" );

    if($instances) {

        my @instance_data = $instances->children_get( "instance-data" );

        foreach my $nic_element (@instance_data) {

            my $nic_name = $nic_element->child_get_string( "uuid" );
            $nic_name =~ s/kernel://;

            my ($node, $nic) = split( /:/, $nic_name );
    
            unless( grep( /$nic/, @{$failed_ports{$node}} )) {

                my $counters = $nic_element->child_get( "counters" );
                if($counters) {

                    my @counter_result = $counters->children_get();

                    foreach my $counter (@counter_result) {
                    
                        my $key = $counter->child_get_string( "name" );
                        my $value = $counter->child_get_string( "value" );

                        if($value > 10) {
                            push(@nic_errors, $nic_name);
                        }
                    }
                }
            }
        }
    }
}

if(@failed_ports && @nic_errors) {
    print "CRITICAL: ";
    print @failed_ports;
    print " in ifgrp and not up\n";
    print join(" ", @nic_errors);
    print " with CRC errors\n";
    exit 2;
} elsif(@failed_ports){
    print "CRITICAL: ";
    print @failed_ports;
    print " in ifgrp and not up\n";
    exit 2;
} elsif(@nic_errors){
    print "CRITICAL: ";
    print join(" ", @nic_errors);
    print " with CRC errors\n";
    exit 2;
} else {
    print "OK: All IFGRP fully active and no CRC errors\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_interfaces - Check cDOT Interface Group Status

=head1 SYNOPSIS

check_cdot_interfaces.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD

=head1 DESCRIPTION

Checks if all Interface Groups have every single link up

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

3 on Unknown Error
2 if any link is down
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
