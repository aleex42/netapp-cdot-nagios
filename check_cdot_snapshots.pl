#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_snapshots - Various check onto volume Snapshots (eg. Old snapshots, existence of specific snapshots, etc... )
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use lib "/usr/lib/netapp-manageability-sdk/lib/perl/NetApp";
use NaServer;
use NaElement;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

GetOptions(
    'hostname=s'        => \my $Hostname,
    'username=s'        => \my $Username,
    'password=s'        => \my $Password,
    'age=i'             => \my $AgeOpt,
    'numbersnapshot=i'  => \my $snapshotnumber,
    'retentiondays=i'   => \my $retention_days,
    'volume=s'          => \my $volumename,
    'busy'              => \my $busy_check,
    'exclude=s'         => \my $excludeliststring,
    'snap_error=s'      => \my $snaperrorstring,
    'help|?'            => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;
$AgeOpt = 3600 * 24 * 90 unless $AgeOpt; # 90 days

my %Excludelist;
my %Snaperrorlist;
my @old_snapshots;
my $now = time;

if ($excludeliststring){
    my @excludelistarray = split(',', $excludeliststring);
    @Excludelist{@excludelistarray}=();
}
if ($snaperrorstring){
    my @snaperrorarray = split(',', $snaperrorstring);
    @Snaperrorlist{@snaperrorarray}=();
}


my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

single_volume_check() if $volumename;

my @snapmirrors = snapmirror_volumes();

my $snap_iterator = NaElement->new("snapshot-get-iter");
my $tag_elem = NaElement->new("tag");
$snap_iterator->child_add($tag_elem);

my $xi = new NaElement('desired-attributes');
$snap_iterator->child_add($xi);
my $xi1 = new NaElement('snapshot-info');
$xi->child_add($xi1);
$xi1->child_add_string('name','name');
$xi1->child_add_string('volume','volume');
$xi1->child_add_string('access-time','access-time');
$xi1->child_add_string('busy','busy');
$xi1->child_add_string('dependency','dependency');

my $next = "";

my %busy_snapshots;
my %wrong_snapshots;

while(defined($next)){
        unless($next eq ""){
            $tag_elem->set_content($next);    
        }

        $snap_iterator->child_add_string("max-records", '10000');
        my $snap_output = $s->invoke_elem($snap_iterator);

        if ($snap_output->results_errno != 0) {
            my $r = $snap_output->results_reason();
            print "UNKNOWN: $r\n";
            exit 3;
        }

        my $snaps = $snap_output->child_get("attributes-list");

        unless($snaps){
            print "OK - No snapshots\n";
            exit 0;
        }

        my @snapshots = $snaps->children_get();

        unless(@snapshots){
            print "OK - No snapshots\n";
            exit 0;
        }
        
        foreach my $snap (@snapshots){
            if (exists $Snaperrorlist{$snap->child_get_string("name")}){
                $wrong_snapshots{$snap->child_get_string("name")} = "VOL: ".$snap->child_get_string("volume");
            }
            if (! exists $Excludelist{$snap->child_get_string("volume")}){
                my $vol_name = $snap->child_get_string("volume");
                my $snap_time = $snap->child_get_string("access-time");
                my $busy_status = $snap->child_get_string("busy");
                my $age = $now - $snap_time;

                if($age >= $AgeOpt){
                    unless(grep(/$vol_name/, @snapmirrors)){
                        my $snap_name  = $snap->child_get_string("name");
                        unless($snap_name =~ m/^clone/ || ($snap->child_get_string("dependency")) =~ /vclone/){
                            push @old_snapshots, "$vol_name/$snap_name";
                        }
                    }
                }
                if ($busy_check){
                    if ($snap->child_get_string("busy") eq "true" && ($snap->child_get_string("dependency")) !~ /snap/){
                        $busy_snapshots{$snap->child_get_string("name")} = $snap->child_get_string("dependency")." - VOL: ".$snap->child_get_string("volume");
                    }
                }
            }
        }
        $next = $snap_output->child_get_string("next-tag");
}

my $busy_snapshots_count = scalar keys %busy_snapshots;
if (@old_snapshots) {
    print "WARNING: ".@old_snapshots . " snapshot(s) older than $AgeOpt seconds ";
    if (%busy_snapshots){
        print "and $busy_snapshots_count are in busy state"
    }
    print ":\n";
    foreach my $snap (@old_snapshots){
        print "$snap\n";
    }
    foreach my $snap (keys %busy_snapshots){
        print "$snap ($busy_snapshots{$snap})\n";
    }
    exit 1;
}
else {
    if (!%busy_snapshots){
        print "OK: No snapshots are older than $AgeOpt seconds\n";
        exit 0;
    } else {
        print "WARNING: There are $busy_snapshots_count snapshots in busy state:\n";
            foreach my $snap (keys %busy_snapshots){
                print "$snap ($busy_snapshots{$snap})\n";
            }
        exit(1);
    }
}

sub snapmirror_volumes {

    my @volumes;

    my $snapmirror_iterator = NaElement->new("snapmirror-get-iter");
    my $snapmirror_tag_elem = NaElement->new("tag");
    $snapmirror_iterator->child_add($snapmirror_tag_elem);

    my $snapmirror_next_tag = "";

    while(defined($snapmirror_next_tag)){
        unless($snapmirror_next_tag eq ""){
            $snapmirror_tag_elem->set_content($snapmirror_next_tag);
        }

        $snapmirror_iterator->child_add_string("max-records", '10000');
        my $snapmirror_output = $s->invoke_elem($snapmirror_iterator);

        if ($snapmirror_output->results_errno != 0) {
            my $r = $snapmirror_output->results_reason();
            print "UNKNOWN: $r\n";
            exit 3;
        }

        if($snapmirror_output->child_get("attributes-list")){
            my @snap_relations = $snapmirror_output->child_get("attributes-list")->children_get();

            if(@snap_relations){

                foreach my $mirror (@snap_relations){
                    my $dest_vol = $mirror->child_get_string("destination-volume");
                    push(@volumes,$dest_vol);
                }
            }
        }
        $snapmirror_next_tag = $snapmirror_output->child_get_string("next-tag");
    }
    return @volumes;
}

sub single_volume_check {
    
    # Declare the variables needed
    
    my $critical_state = "false";
    my $warning_state = "false";
    my $temp_best_snap = "";
    my $timestamp_best_snap = -1;
    my $snaptime_second = $retention_days*86400;
    my $found = 0;
    my @snapshot_list;
    my $now = time;
    my %busy_snapshots;
    
    # Create the XML code to be submitted to the CDOT Cluster

    my $api = new NaElement('snapshot-get-iter');
    my $xi = new NaElement('desired-attributes');
    $api->child_add($xi);
    my $xi1 = new NaElement('snapshot-info');
    $xi->child_add($xi1);
    $xi1->child_add_string('access-time');
    $xi1->child_add_string('name','name');
    $xi1->child_add_string('volume','volume');
    $xi1->child_add_string('access-time','access-time');
    $xi1->child_add_string('busy','busy');
    $xi1->child_add_string('dependency','dependency');
    my $xi2 = new NaElement('query');
    $api->child_add($xi2);
    my $xi3 = new NaElement('snapshot-info');
    $xi2->child_add($xi3);
    $xi3->child_add_string('volume',$volumename);
    $api->child_add_string('max-records','10000');
    
    my $xo = $s->invoke_elem($api);
    if ($xo->results_status() eq 'failed') {
        print 'Error:\n';
        print $xo->sprintf();
        exit 1;
    }

    my $current_snap_num = 0; 
    $current_snap_num = $xo->child_get_int("num-records");

    if ($snapshotnumber != 0 && $current_snap_num != 0){
        
        my $attr_list = $xo->child_get("attributes-list");
        @snapshot_list = $attr_list->children_get();

        foreach my $snap(@snapshot_list){
            my $snap_create_time = $snap->child_get_int("access-time");
            if($now - $snap_create_time <= $snaptime_second){
                if($found == 0){
                    $found = 1;
                    last;
                } 
            } elsif ($timestamp_best_snap - $snap_create_time < 0){
                $timestamp_best_snap = $snap_create_time;
            } elsif ($timestamp_best_snap == -1){
                $timestamp_best_snap = $snap_create_time;
            }
        }
        if (!$busy_check){
            foreach my $snap (@snapshot_list){
                    if ($snap->child_get_string("busy") eq "true"){
                        $busy_snapshots{$snap->child_get_string("name")} = $snap->child_get_string("dependency");
                    }
            }
        }
        my $busy_snapshots_count = scalar keys %busy_snapshots;
        if ($current_snap_num != $snapshotnumber){
            print "WARNING: The snapshot number is different from the requested (".$current_snap_num."!=".$snapshotnumber.")";
            if (%busy_snapshots){
                print "[...]\nThere are also $busy_snapshots_count snapshots in busy state:\n";
                foreach my $snap (keys %busy_snapshots){
                    print "$snap ($busy_snapshots{$snap})\n";
                }
            } else {
                print "\n";
            }
            exit(1);
        }
        if ($found == 1){
            if (!%busy_snapshots){
                print "OK - Snapshots OK\n";
                exit(0);
            } else {
                print "WARNING: There are $busy_snapshots_count snapshots in busy state:\n";
                foreach my $snap (keys %busy_snapshots){
                    print "$snap ($busy_snapshots{$snap})\n";
                }
                exit(1);
            }
        } else {
            print "CRITICAL: The newest snapshot is older than the time requested (".sprintf("%.2f", (($now - $timestamp_best_snap)/86400))."!=".$retention_days." gg)";
            if (%busy_snapshots){
                print "[...]\nThere are also $busy_snapshots_count snapshots in busy state:\n";
                foreach my $snap (keys %busy_snapshots){
                    print "$snap ($busy_snapshots{$snap})\n";
                }
            } else {
                print "\n";
            }
            exit(2);
        }
    } else {
        if ($current_snap_num != 0 && $snapshotnumber == 0){
            print "CRITICAL: There are snapshots for a volume that shouldn't have any";
            if (%busy_snapshots){
                print "[...]\nThere are also $busy_snapshots_count snapshots in busy state:\n";
                foreach my $snap (keys %busy_snapshots){
                    print "$snap ($busy_snapshots{$snap})\n";
                }
            } else {
                print "\n";
            }
            exit(2);
        }elsif ($current_snap_num == 0 && $snapshotnumber != 0){
            print "WARNING: The number of snapshots is different from the expected (".$current_snap_num."!=".$snapshotnumber.")";
            if (%busy_snapshots){
                print "[...]\nThere are also $busy_snapshots_count snapshots in busy state:\n";
                foreach my $snap (keys %busy_snapshots){
                    print "$snap ($busy_snapshots{$snap})\n";
                }
            } else {
                print "\n";
            }
            exit(1);
        }else{
            print "OK: No snapshot for the requested volume\n";
            exit(0);
        }
    } 
}
__END__

=encoding utf8

=head1 NAME

check_cdot_snapshots - Various check onto volume Snapshots (eg. Old snapshots, existence of specific snapshots, etc... )

=head1 SYNOPSIS

check_cdot_snapshots.pl --hostname HOSTNAME \
    --username USERNAME --password PASSWORD [--age AGE-SECONDS] \
    [--numbersnapshot NUMBER-ITEMS] [--retentiondays AGE-DAYS] \
    [--volume VOLUME-NAME] [--busy] [--exclude VOLUME-NAME[,VOLUME-NAME]] \
    [--snap_error SNAPSHOT-NAME[,SNAPSHOT-NAME]]

=head1 DESCRIPTION

Various check onto volume Snapshots. You can check, eg., the oldness of the snapshots of the entire CDOT or of a single volume, whether exists a specific snapshot inside 

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to monitor

=item --username USERNAME

The Login Username of the NetApp to monitor

=item --password PASSWORD

The Login Password of the NetApp to monitor

=item --age AGE-SECONDS

Snapshot age in Seconds. Default 90 days

=item --volume VOLUME-NAME

Name of the single snapshot that has to be checked (useful for check that a snapshot retention works)

=item --numbersnapshot NUMBER-ITEMS

The number of snapshots that should be present in VOLUME volume (useful for check that a snapshot retention works)

=item --retentiondays AGE-DAYS

Snapshot age in days of the newest snapshot in VOLUME volume (useful for check that a snapshot retention works)

=item --busy 

Check whether there are snapshot in busy state

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 if timeout occured
1 if Warning Threshold (90 days) has been reached
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stelios Gikas <sgikas at demokrit.de>
