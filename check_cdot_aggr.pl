#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_aggr - Check Aggregate real Space Usage
# Copyright (C) 2013 noris network AG, http://www.noris.net/
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
use Getopt::Long;
use Data::Dumper;

GetOptions(
    'hostname=s' => \my $Hostname,
    'username=s' => \my $Username,
    'password=s' => \my $Password,
    'warning=i'  => \my $Warning,
    'critical=i' => \my $Critical,
    'aggr=s'     => \my $Aggr,
    'perf'       => \my $perf,
    'exclude=s'  => \my @excludelistarray,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

my %Excludelist;
@Excludelist{@excludelistarray}=();

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;
Error('Option --warning needed!')  unless $Warning;
Error('Option --critical needed!') unless $Critical;

my $perfmsg;
my $message;
my $critical = 0;
my $warning = 0;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $iterator = NaElement->new("aggr-get-iter");
my $tag_elem = NaElement->new("tag");
$iterator->child_add($tag_elem);

my $xi = new NaElement('desired-attributes');
$iterator->child_add($xi);
my $xi1 = new NaElement('aggr-attributes');
$xi->child_add($xi1);
$xi1->child_add_string('aggregate-name','<aggregate-name>');
my $xi2 = new NaElement('aggr-space-attributes');
$xi1->child_add($xi2);
$xi2->child_add_string('percent-used-capacity','<percent-used-capacity>');
$xi2->child_add_string('size-available','<size-available>');
$xi2->child_add_string('size-total','<size-total>');
$xi2->child_add_string('size-used','<size-used>');
my $xi3 = new NaElement('query');
$iterator->child_add($xi3);
my $xi4 = new NaElement('aggr-attributes');
$xi3->child_add($xi4);
if($Aggr){
    $xi4->child_add_string('aggregate-name',$Aggr);
}
my $xi5 = new NaElement('query');
$iterator->child_add($xi5);

my $next = "";

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

    my $aggrs = $output->child_get("attributes-list");
    my @result = $aggrs->children_get();

    foreach my $aggr (@result){

        

        my $aggr_name = $aggr->child_get_string("aggregate-name");

        unless($aggr_name =~ m/^aggr0_/){

            next if exists $Excludelist{$aggr_name};

            my $space = $aggr->child_get("aggr-space-attributes");
            my $percent = $space->child_get_int("percent-used-capacity");

            $critical++ if $percent >= $Critical;
            $warning++  if $percent >= $Warning;

            if ($message) {
                $message .= ", " . $aggr_name . " (" . $percent . "%)";
            }
            else {
                $message .= $aggr_name . " (" . $percent . "%)";
            }   

            if ($perf) {
                $perfmsg .= " $aggr_name=$percent%;$Warning;$Critical";
            }
            else {
                $perfmsg .= "$aggr_name=$percent%;$Warning;$Critical";
            }   
        }
    }

    $next = $output->child_get_string("next-tag");
}

if($critical > 0){
    print "CRITICAL: " . $message;
    if($perf) {print"|" . $perfmsg;}
    print  "\n";
    exit 2;
} elsif($warning > 0){
    print "WARNING: " . $message;
    if($perf){print"|" . $perfmsg;}
    print  "\n";    
    exit 1;
} else {
    print "OK: " . $message;
    if($perf){print"|" . $perfmsg;}    
    print  "\n";    
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_aggr - Check Aggregate real Space Usage

=head1 SYNOPSIS

check_cdot_aggr.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD --warning PERCENT_WARNING \
           --critical PERCENT_CRITICAL (--perf) (--aggr AGGR)

=head1 DESCRIPTION

Checks the Aggregate real Space Usage of the NetApp System and warns
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

=item --perf

Flag for performance data output

=item --aggr

Check only specific aggregate

=item --exclude

Optional: The name of an aggregate that has to be excluded from the checks (multiple exclude item for multiple aggregates)

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
 Stelios Gikas <sgikas at demokrit.de>
 Stefan Grosser <sgr at firstframe.net>
 Stephan Lang <stephan.lang at acp.at>

