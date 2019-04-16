#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_effiency - Check Efficiency Settings
# Copyright (C) 2019 noris network AG, http://www.noris.net/
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
use Time::HiRes qw();

my $STARTTIME_HR = Time::HiRes::time();           # time of program start, high res
my $STARTTIME    = sprintf("%.0f",$STARTTIME_HR); # time of program start

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

my $iterator = NaElement->new("volume-get-iter");
my $tag_elem = NaElement->new("tag");
$iterator->child_add($tag_elem);

my $xi = new NaElement('desired-attributes');
$iterator->child_add($xi);
my $xi1 = new NaElement('volume-attributes');
$xi->child_add($xi1);
my $xi2 = new NaElement('volume-id-attributes');
$xi1->child_add($xi2);
$xi2->child_add_string('name','<name>');
$xi2->child_add_string('type','<type>');
my $xi3 = new NaElement('volume-space-attributes');
$xi1->child_add($xi3);
$xi3->child_add_string('is-space-reporting-logical');
$xi3->child_add_string('is-space-enforcement-logical');
my $xi4 = new NaElement('query');
$iterator->child_add($xi4);
my $xi5 = new NaElement('volume-attributes');
$xi4->child_add($xi5);

my $next = "";

my @crit_msg;

while(defined($next)){
    unless($next eq ""){
        $tag_elem->set_content($next);    
    }

    $iterator->child_add_string("max-records", 100);
    my $output = $s->invoke_elem($iterator);

    if ($output->results_errno != 0) {
        my $r = $output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }
    
    my $volumes = $output->child_get("attributes-list");
    
    unless($volumes){
        print "CRITICAL: no volume matching this name\n";
        exit 2;
    }
    
    my @result = $volumes->children_get();

    foreach my $vol (@result){

        my $vol_info = $vol->child_get("volume-id-attributes");
        my $type = $vol_info->child_get_string("type");
        my $vserver_name = $vol_info->child_get_string("owning-vserver-name");
        my $vol_name = "$vserver_name/" . $vol_info->child_get_string("name");
    
        next if $vol_info->child_get_string("name") eq "vol0";
        next if $vol_info->child_get_string("name") =~ m/_root$/;
        next if $type eq "dp";

        my $vol_space = $vol->child_get("volume-space-attributes");

        my $reporting = $vol_space->child_get_string("is-space-reporting-logical");
        my $enforcement = $vol_space->child_get_string("is-space-enforcement-logical");

        if(($reporting ne "true") || ($enforcement ne "true")){
            push(@crit_msg, $vol_name);
        }
    }
    $next = $output->child_get_string("next-tag");
}

if(scalar(@crit_msg) ){
    print "CRITICAL: wrong volume efficiency settings:\n";
    print join (" ", @crit_msg);
    print "\n";
    exit 2;
} else {
    print "OK: all volume efficiency settings ok\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_effiency - Check Efficiency Settings

=head1 SYNOPSIS

check_cdot_efficiency.pl -H HOSTNAME -u USERNAME -p PASSWORD 

=head1 DESCRIPTION

Checks the Volume Efficiency Settings

=head1 OPTIONS

=over 4

=item -H | --hostname FQDN

The Hostname of the NetApp to monitor

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
2 if Critical Threshold has been reached
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>

