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

use lib "/usr/lib/netapp-manageability-sdk/lib/perl/NetApp";
use NaServer;
use NaElement;
use Getopt::Long qw(:config no_ignore_case);

my $critical = 2;
my $warning = 1;
GetOptions(
    'H|hostname=s' => \my $Hostname,
    'u|username=s' => \my $Username,
    'p|password=s' => \my $Password,
    'w|warning=i' => \$warning,
    'c|critical=i' => \$critical,
    'd|diskcount=i' => \my $Diskcount,
    'P|perf' => \my $perf,
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

my $iterator = NaElement->new("storage-disk-get-iter");
my $tag_elem = NaElement->new("tag");
$iterator->child_add($tag_elem);

my $next = "";
my $disk_count = 0;
my @disk_list;
my %inventory = ( 'Spare', 0, 'Rebuilding', 0, 'Aggregate', 0, 'Failed', 0);

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

    unless($output->child_get_int("num-records") eq "0"){

        my $disks = $output->child_get("attributes-list");
        my @result = $disks->children_get();

        foreach my $disk (@result) {
            my $raid_type = $disk->child_get("disk-raid-info");
            my $container = $raid_type->child_get_string('container-type');

            $disk_count++;

            if ( $container eq 'shared' ) {
                # Dig deeper
                my $shared_info = $raid_type->child_get("disk-shared-info");
                my $temp = $shared_info->child_get_string('is-reconstructing');
                if ($temp eq 'true') {
                    $inventory{'Rebuilding'}++;
                } else {
                    $temp = $shared_info->child_get_string('is-replacing');
                    if ($temp eq 'true') {
                        # Also count as Rebuilding
                        $inventory{'Rebuilding'}++;
                    } else {
                        $inventory{'Aggregate'}++;
                    }
                }
            } elsif ( $container eq 'spare' ) {
                $inventory{'Spare'}++;
            } elsif ( $container eq 'aggregate' ) {
                # Dig deeper
                my $aggr_info = $raid_type->child_get('disk-aggregate-info');
                my $temp = $aggr_info->child_get_string('is-reconstructing');
                if ($temp eq 'true') {
                    $inventory{'Rebuilding'}++;
                } else {
                    $temp = $aggr_info->child_get_string('is-replacing');
                    if ($temp eq 'true') {
                        # Also count as Rebuilding
                        $inventory{'Rebuilding'}++;
                    } else {
                        $inventory{'Aggregate'}++;
                    }
                }
            } else {
                my $owner = $disk->child_get("disk-ownership-info");
                my $diskstate = $owner->child_get_string('is-failed');
                if (( $diskstate eq 'true' ) && ($container ne 'maintenance')) {
                    push @disk_list, $disk->child_get_string('disk-name');
                    $inventory{'Failed'}++;
                } else {
                    $inventory{'Aggregate'}++;
                }
            }
        }
    }
    $next = $output->child_get_string("next-tag");

}

my $perfdatastr='';
$perfdatastr = sprintf(" | Aggregate=%dDisks Spare=%dDisks Rebuilding=%dDisks Failed=%dDisks",
    $inventory{'Aggregate'}, $inventory{'Spare'}, $inventory{'Rebuilding'}, $inventory{'Failed'}
) if ($perf);

if ( scalar @disk_list >= $critical ) {
    print "CRITICAL: " . @disk_list . ' failed disk(s): ' . join( ', ', @disk_list ) . $perfdatastr ."\n";
    exit 2;
} elsif ( scalar @disk_list >= $warning ) {
    print "WARNING: " . @disk_list .' failed disk(s): ' .join( ', ', @disk_list ) . $perfdatastr ."\n";
    exit 1;
} elsif(($Diskcount) && ($Diskcount ne $disk_count)){
    my $diff = $Diskcount-$disk_count;
    print "CRITICAL: $diff disk(s) missing".$perfdatastr."\n";
    exit 2;
} else {
    print "OK: All $disk_count disks OK".$perfdatastr."\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_disk - Checks Disk Healthness

=head1 SYNOPSIS

check_cdot_disk.pl -H HOSTNAME -u USERNAME -p PASSWORD [-d COUNT]

=head1 DESCRIPTION

Checks if there are some damaged disks.

=head1 OPTIONS

=over 4

=item -H | --hostname FQDN

The Hostname of the NetApp to monitor

=item -u | --username USERNAME

The Login Username of the NetApp to monitor

=item -p | --password PASSWORD

The Login Password of the NetApp to monitor

=item -d | --disks COUNT

Expected number of disks to find

=item -help

=item -h

to see this Documentation

=back

=head1 EXIT CODE

3 if timeout occured
2 if there are some damaged disks
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stelios Gikas <sgikas at demokrit.de>

