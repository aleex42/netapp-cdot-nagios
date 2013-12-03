#!/usr/bin/perl

# --
# check_cdot_volume - Check Volume Space Usage
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

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
    'warning=i'  => \my $Warning,
    'critical=i' => \my $Critical,
    'volume=s'   => \my $Volume,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;
Error('Option --warning needed!')  unless $Warning;
Error('Option --critical needed!') unless $Critical;
Error('Option --volume needed!') unless $Volume;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $api = new NaElement('volume-get-iter');
my $xi = new NaElement('desired-attributes');
$api->child_add($xi);
my $xi1 = new NaElement('volume-attributes');
$xi->child_add($xi1);
my $xi2 = new NaElement('volume-id-attributes');
$xi1->child_add($xi2);
$xi2->child_add_string('name','<name>');
my $xi3 = new NaElement('volume-space-attributes');
$xi1->child_add($xi3);
$xi3->child_add_string('percentage-size-used','<percentage-size-used>');
$xi3->child_add_string('size-used','<size-used>');
$xi3->child_add_string('size-total','<size-total>');
$xi3->child_add_string('percentage-snapshot-reserve','<percentage-snapshot-reserve>');
$xi3->child_add_string('percentage-snapshot-reserve-used','<percentage-snapshot-reserve-used>');

my $xi4 = new NaElement('query');
$api->child_add($xi4);
my $xi5 = new NaElement('volume-attributes');
$xi4->child_add($xi5);
my $xi6 = new NaElement('volume-id-attributes');
$xi5->child_add($xi6);
$xi6->child_add_string('name',$Volume);

my $output = $s->invoke_elem($api);

if ($output->results_errno != 0) {
    my $r = $output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $volumes = $output->child_get("attributes-list");
my @result = $volumes->children_get();

my $matching_volumes = @result;

if($matching_volumes > 1){
    print "CRITICAL: more than one volume matching this name";
    exit 2;
}

foreach my $vol (@result){
    
    my $vol_info = $vol->child_get("volume-id-attributes");
    my $vol_name = $vol_info->child_get_string("name");
    
    my $vol_space = $vol->child_get("volume-space-attributes");
    
    my $percent = $vol_space->child_get_int("percentage-size-used");
    my $snap_reserv_used = $vol_space->child_get_int("percentage-snapshot-reserve-used");
    my $snap_reserv = $vol_space->child_get_int("percentage-snapshot-reserve");
    my $used = $vol_space->child_get_int("size-used");
    my $total = $vol_space->child_get_int("size-total");

    my $snap_used = $snap_reserv_used*$snap_reserv*$total*0.0001;

    $used += $snap_used;
    $used /= 1024*1024*1024;
    my $rounded_used = sprintf "%.2f", $used;

    $total += (0.01*$snap_reserv*$total);
    $total /= 1024*1024*1024;
    my $rounded_total = sprintf "%.2f", $total;

    
    if($percent >= $Critical){
        print "CRITICAL: $percent% (${rounded_used} GB / ${rounded_total} GB)\n";
        exit 2;
    } elsif($percent >= $Warning){
        print "WARNING: $percent% (${rounded_used} GB / ${rounded_total} GB)\n";
        exit 1;
    } else {
        print "OK: $percent% (${rounded_used} GB / ${rounded_total} GB)\n";
        exit 0;
    }
}

__END__

=encoding utf8

=head1 NAME

check_cdot_volume - Check Volume Space Usage

=head1 SYNOPSIS

check_cdot_aggr.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD --warning PERCENT_WARNING \
           --critical PERCENT_CRITICAL --volume VOLUME

=head1 DESCRIPTION

Checks the Volume Space Usage of the NetApp System and warns
if warning or critical Thresholds are reached

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to monitor

=item --username USERNAME

The Login Username of the NetApp to monitor

=item --password PASSWORD

The Login Password of the NetApp to monitor

=item --warning PERCENT_WARNING

The Warning threshold

=item --critical PERCENT_CRITICAL

The Critical threshold

=item --volume VOLUME

The name of the Volume to check

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 on Unknown Error
2 if Critical Threshold has been reached
1 if Warning Threshold has been reached
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
