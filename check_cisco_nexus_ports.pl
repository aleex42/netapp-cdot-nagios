#!/usr/bin/perl

# nagios: -epn
# --
# check_cisco_nexus_ports - Check Cisco Nexus Port State
# Copyright (C) 2017 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use 5.014;
use strict;
use warnings;

use Net::SNMP;

use Getopt::Long qw(:config no_ignore_case);

GetOptions(
    'H|hostname=s' => \my $host,
    'p|community=s' => \my $comm,
    'h|help'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

my $domain = "udp/ipv4";

my ( $session, $error ) = Net::SNMP->session(
    -hostname => $host,
    -community => $comm,
    -domain    => $domain,
    -version   => "2",
);
die "Error: cannot connect to host $host: $error\n" unless $session;

my $interfaceData='1.3.6.1.2.1.2.2.1';
my $interface_all = $session->get_table( Baseoid => $interfaceData);

my $interfaceIndex='1.3.6.1.2.1.2.2.1.2';
my $interfaces = $session->get_table( Baseoid => $interfaceIndex);

my @mismatch;

for my $interface (keys %$interfaces) {

	if ($interface =~ m/^1.3.6.1.2.1.2.2.1.2./){

		my $last_num = $interface;
		$last_num =~ s/^1.3.6.1.2.1.2.2.1.2.//;

		my $if_name = $$interfaces{$interface};

		my $admin_status = $$interface_all{"1.3.6.1.2.1.2.2.1.7.$last_num"};
		my $oper_status = $$interface_all{"1.3.6.1.2.1.2.2.1.8.$last_num"};

		if($admin_status != $oper_status){
			push(@mismatch, $if_name);
		}
	}
}

if($#mismatch > 0){
	print "CRITICAL: Interface status mismatch:\n";
	print join(", ",@mismatch);
	print "\n";
	exit 2;
} else {
	print "OK: Interface status match\n";
	exit 0;
}
