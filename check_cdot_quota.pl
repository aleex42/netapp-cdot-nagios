#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_quota - Check quota usage
# Copyright (C) 2016 Joshua Malone (jmalone@nrao.edu)
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

GetOptions(
    'H|hostname=s' => \my $Hostname,
    'u|username=s' => \my $Username,
    'p|password=s' => \my $Password,
    'w|warning=i'  => \my $SizeWarning,
    'c|critical=i' => \my $SizeCritical,
    'P|perf'     => \my $perf,
    "V|volume=s" => \my $Volume,
    't|target=s'   => \my $Quota,
    'vserver=s' => \my $Vserver,
    'v|verbose' => \my $verbose,
    'h|help'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "UNKNOWN: $0: " . $_[0] . "\n";
    exit 3;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;
Error('Option -w needed!')  unless $SizeWarning;
Error('Option -c needed!') unless $SizeCritical;
Error('Critical space threshold must be greater than Warning!') if ($SizeWarning > $SizeCritical);
if ($Quota && !$Volume) {
    Error('Option -t requires a Volume name (-V)!');
}

# Set some conservative default thresholds for the more
# esoteric metrics

my ($crit_msg, $warn_msg, $ok_msg);
# Store all perf data points for output at end
my %perfdata=();

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $iterator = NaElement->new("quota-report-iter");
my $tag_elem = NaElement->new("tag");
$iterator->child_add($tag_elem);

my $quota_query = NaElement->new("query");
my $quota_info = NaElement->new("quota");

if ($Volume) {
    print("Querying only volume $Volume\n") if ($verbose);
    $iterator->child_add($quota_query);
    $quota_query->child_add($quota_info);
    $quota_info->child_add_string('volume', $Volume);
}
if ($Quota) {
    $quota_info->child_add_string('quota-target', $Quota);
}

if ($Vserver) {
    $quota_info->child_add_string('vserver', $Vserver);
}

my $next = "";
my (@crit_msg, @warn_msg, @ok_msg);

while(defined($next)){
    unless($next eq ""){
        $tag_elem->set_content($next);
    }
    $iterator->child_add_string("max-records", 100);
    my $output = $s->invoke_elem($iterator);
    last if ($output->child_get_string("num-records") == 0 );

    if ($output->results_errno != 0) {
            my $r = $output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }

    foreach my $getQuota ( $output->child_get("attributes-list")->children_get() ) {

        # Disk limit is in KB
        my $diskLimit = $getQuota->child_get_string('disk-limit');

        next if ($diskLimit eq "-" or $diskLimit == 0 );

        # Also in KB
        $diskLimit *= 1024;
        my $diskUsed = $getQuota->child_get_string('disk-used') * 1024;
        my $fileLimit = $getQuota->child_get_string('file-limit');
        my $filesUsed = $getQuota->child_get_string('files-used');
        my $volume = $getQuota->child_get_string('volume');
        my $type = $getQuota->child_get_string('quota-type');
        my $target;
        if ($type eq "user") {
            my $qUsers = $getQuota->child_get('quota-users');
            next unless ($qUsers);
            my $qUser= $qUsers->child_get('quota-user');
            next unless ($qUser);
            my $quotaUser = $qUser->child_get_string('quota-user-name');
            printf("Found quota for %s on %s\n", $quotaUser, $volume) if ($verbose);
            $target = sprintf("%s/%s", $volume, $quotaUser);
        } else {
            $target = $getQuota->child_get_string('quota-target');
        }
        printf ("Quota %s: %s %s %s %s\n", $target, $diskLimit, $diskUsed, $fileLimit, $filesUsed) if ($verbose);
        my $diskPercent=($diskUsed/$diskLimit*100);

        # Generate pretty-printed scaled numbers
        my $msg = sprintf ("Quota %s is %d%% full (used %s of %s)",
            $target, $diskPercent, humanScale($diskUsed), humanScale($diskLimit) );
        if ($diskPercent >= $SizeCritical) {
            push (@crit_msg, $msg);
        } elsif ($diskPercent >= $SizeWarning) {
            push (@warn_msg, $msg);
        } else {
            push (@ok_msg, $msg);
        }
        if ($fileLimit ne "-" ) {
            # Check files limit as well as space
        }

        if ($perf) {
            $perfdata{$target}{'byte_used'}=$diskUsed;
            $perfdata{$target}{'byte_total'}=$diskLimit;
            $perfdata{$target}{'files_used'}=$filesUsed;
            $perfdata{$target}{'file_limit'}=$fileLimit;
        }
    }
    $next = $output->child_get_string("next-tag");
}

# Build perf data string for output
my $perfdatastr="";
if ($perf) {
    foreach my $vol ( keys(%perfdata) ) {
        # DS[1] - Data space used
        $perfdatastr.=sprintf(" %s_space_used=%dB;%d;%d;%d;%d", $vol, $perfdata{$vol}{'byte_used'},
            $SizeWarning*$perfdata{$vol}{'byte_total'}/100, $SizeCritical*$perfdata{$vol}{'byte_total'}/100,
            0, $perfdata{$vol}{'byte_total'} );
    }
}

if(scalar(@crit_msg) ){
    print "CRITICAL: ";
    print join (". ", @crit_msg);
    if(scalar(@warn_msg)){
        print "\nWARNING: ";
        print join (", ", @warn_msg);
    }
    if(scalar(@ok_msg)){
        print "\nOK: ";
        print join (", ", @ok_msg);
    }
    print "|$perfdatastr\n" if ($perf);
    exit 2;
} elsif(scalar(@warn_msg) ){
    print "WARNING: ";
    print join ("; ", @warn_msg);
    if(scalar(@ok_msg)){
        print "\nOK: ";
        print join (", ", @ok_msg);
    }
    print "|$perfdatastr\n" if ($perf);
    exit 1;
} elsif(scalar(@ok_msg) ){
    print "OK: ";
    print join (", ", @ok_msg);
    print "|$perfdatastr\n" if ($perf);
    exit 0;
} else {
    print "WARNING: no online volume found\n";
    exit 1;
}

sub humanScale {
    my ($metric) = @_;
    my $unit='B';
    my @units = qw( KB MB GB TB PB EB );
    while ($metric > 1100) {
        if (scalar(@units)<1) {
            # Hit our max scaling factor - bail out
            last;
        }
        $unit=shift(@units);
        $metric=$metric/1024;
    }
    return sprintf("%.1f %s", $metric, $unit);
}

__END__

=encoding utf8

=head1 NAME

check_cdot_volume - Check Volume Usage

=head1 SYNOPSIS

check_cdot_quota.pl -H HOSTNAME -u USERNAME -p PASSWORD
           -w PERCENT_WARNING -c PERCENT_CRITICAL
           [--files-warning PERCENT_WARNING]
           [--files-critical PERCENT_CRITICAL]
           [-t quota_target_path] [-V VOLUME] [-P]

=head1 DESCRIPTION

Checks the space and files usage of a quota / qtree and alerts
if warning or critical thresholds are reached

=head1 OPTIONS

=over 4

=item -H | --hostname FQDN

The Hostname of the NetApp to monitor (Cluster or Node MGMT)

=item -u | --username USERNAME

The Login Username of the NetApp to monitor

=item -p | --password PASSWORD

The Login Password of the NetApp to monitor

=item -w PERCENT_WARNING

The Warning threshold for data space usage.

=item -c PERCENT_CRITICAL

The Critical threshold for data space usage.

=item -V | --volume VOLUME

Optional: The name of the Volume on which quotas should be checked.

=item -t | --target TARGET

Optional: The target of a specific quota / qtree that should be checked.
To use this option, you **MUST** specify a  volume.

=item -help

=item -h

to see this Documentation

=back

=head1 EXIT CODE

3 on Unknown Error
2 if Critical Threshold has been reached
1 if Warning Threshold has been reached or any problem occured
0 if everything is ok

=head1 AUTHORS

 Joshua Malone <jmalone at nrao.edu>
 Alexander Krogloth <git at krogloth.de>
 Stefan Grosser <sgr at firstframe.net>
