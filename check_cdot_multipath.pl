#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_multipath - Check if all disks are multipathed (4 paths)
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use Data::Dumper;

use 5.10.0;
use strict;
use warnings;

use lib "/usr/lib/netapp-manageability-sdk/lib/perl/NetApp";
use NaServer;
use NaElement;
use Getopt::Long;

GetOptions(
    'hostname=s' => \my $Hostname,
    'username=s' => \my $Username,
    'password=s' => \my $Password,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("check_cdot_aggr: Error in command line arguments\n");

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;

my $must_paths;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

# MCC check
my $mcc_iterator = NaElement->new("metrocluster-get");
my $mcc_response = $s->invoke_elem($mcc_iterator);

my $mcc = $mcc_response->child_get("attributes");
my $mcc_info = $mcc->child_get("metrocluster-info");
my $config_state = $mcc_info->child_get_string("local-configuration-state");

if($config_state eq "configured"){

    my $type = $mcc_info->child_get_string("configuration-type");

    if($type eq "stretch"){
        $must_paths = 2;
    } elsif($type eq "fabric"){
        $must_paths = 8;
    } else {
        $must_paths = 4;
    }
} else {
    $must_paths = 4;
}

my $iterator = NaElement->new("storage-disk-get-iter");
my $tag_elem = NaElement->new("tag");
$iterator->child_add($tag_elem);

my $next = "";
my @failed_disks;

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
	
	my $heads = $output->child_get("attributes-list");
	my @result = $heads->children_get();

	foreach my $disk (@result){
	
	    my $paths = $disk->child_get("disk-paths");
	    my $path_count = $paths->children_get("disk-path-info");
	    my $disk_name = $disk->child_get_string("disk-name");
        my $path_info = $paths->child_get("disk-path-info");

        foreach my $path ($path_info){

            my $disk_path_name = $path->child_get_string("disk-name");
            my @split = split(/:/,$disk_path_name);

            if((@split eq 2) && ($path_count ne $must_paths)){
                unless($path_count > $must_paths){
                    push @failed_disks, $disk_name;
                }
            }
        }
	}
	$next = $output->child_get_string("next-tag");
}

if (@failed_disks) {
    print 'CRITICAL: disk(s) not multipath: ' . join( ', ', @failed_disks ) . "\n";
    exit 2;
} else {
    print "OK: All disks multipath\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_multipath - Check if all disks are multipathed (4 paths)

=head1 SYNOPSIS

check_cdot_multipath.pl --hostname HOSTNAME --username USERNAME \
    --password PASSWORD

=head1 DESCRIPTION

Checks if all Disks are multipathed (4 paths)

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

3 if timeout occured
2 if one or more disks doesn't have 4 Paths
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stelios Gikas <sgikas at demokrit.de>
