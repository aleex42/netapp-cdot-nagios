#!/usr/bin/perl

# --
# check_cdot_rebuild - Check Aggregate State
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
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
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

my $output = $s->invoke("aggr-get-iter");

if ($output->results_errno != 0) {
    my $r = $output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $aggrs = $output->child_get("attributes-list");
my @result = $aggrs->children_get();

my @failed_aggrs;

foreach my $aggr (@result){

    my $aggr_name = $aggr->child_get_string("aggregate-name");

    my $raid = $aggr->child_get("aggr-raid-attributes");
    my $plex_list=$raid->child_get("plexes");
    my @plexes = $plex_list->children_get();

    foreach my $plex (@plexes){

        my $rg_list = $plex->child_get("raidgroups");
        my @rgs = $rg_list->children_get();

        foreach my $rg (@rgs){

            my $rg_reconstruct = $rg->child_get_string("is-reconstructing");

            if($rg_reconstruct eq "true"){
                unless(grep(/$aggr_name/, @failed_aggrs)){
                    push(@failed_aggrs, $aggr_name);
                }
            }
        }
    }
}

if(@failed_aggrs){
    print "CRITICAL: aggregate(s) rebuilding: ";
    print join(", ",@failed_aggrs . "\n");
    print "\n";
    exit 2;
} else {
    print "OK: no aggregate(s) rebuilding\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_rebuild - Check Aggregate State

=head1 SYNOPSIS

check_cdot_rebuild.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD 

=head1 DESCRIPTION

Checks the Aggregate RAID-Status (reconstructing) of the NetApp System and warns
critical if any raidgroup is reconstructing

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
2 if any reconstruct is running
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
