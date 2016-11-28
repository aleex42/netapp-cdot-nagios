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
        my $r = $ifgrp_output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
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
    my @lif_result = $lifs->children_get();

    foreach my $lif (@lif_result) {

        my $node = $lif->child_get_string( "node" );
        my $name = $lif->child_get_string( "port" );
        my $state = $lif->child_get_string( "link-status" );

        if ($state ne "up") {
            push( @{$failed_ports{$node}}, $name );
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

if (@failed_ports) {
    print "CRITICAL: ";
    print @failed_ports;
    print " in ifgrp and not up\n";
    exit 2;
} else {
    print "OK: All IFGRP fully active\n";
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
