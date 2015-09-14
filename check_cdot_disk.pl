#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_disk - Check NetApp System Disk State
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
    'diskcount=i' => \my $Diskcount,
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

my $iterator = NaElement->new("storage-disk-get-iter");
my $tag_elem = NaElement->new("tag");
$iterator->child_add($tag_elem);

my $next = "";
my $disk_count = 0;
my @disk_list;

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
	
	my $disks = $output->child_get("attributes-list");
	my @result = $disks->children_get();
	
	foreach my $disk (@result) {
	
	    $disk_count++;
	
	    my $owner = $disk->child_get("disk-ownership-info");
	    my $diskstate = $owner->child_get_string('is-failed');
	    if ( $diskstate eq 'true' ) {
	        push @disk_list, $disk->child_get_string('disk-name');
	    }
	}
	$next = $output->child_get_string("next-tag");
}

if (@disk_list) {
    print "CRITICAL" . @disk_list . ' failed disk(s): ' . join( ', ', @disk_list ) . "\n";
    exit 2;
} elsif(($Diskcount) && ($Diskcount ne $disk_count)){
    my $diff = $Diskcount-$disk_count;
    print "CRITICAL: $diff disk(s) missing\n";
    exit 2;
} else {
    print "OK: All $disk_count disks OK\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_disk - Checks Disk Healthness

=head1 SYNOPSIS

check_cdot_disk.pl --hostname HOSTNAME \
    --username USERNAME --password PASSWORD

=head1 DESCRIPTION

Checks if there are some damaged disks.

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
2 if there are some damaged disks
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stelios Gikas <sgikas at demokrit.de>

