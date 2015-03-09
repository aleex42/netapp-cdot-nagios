#!/usr/bin/perl

# --
# check_cdot_volume - Check Volume Usage
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
    'size-warning=i'  => \my $SizeWarning,
    'size-critical=i' => \my $SizeCritical,
    'inode-warning=i'  => \my $InodeWarning,
    'inode-critical=i' => \my $InodeCritical,
    'perf'     => \my $perf,
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
Error('Option --size-warning needed!')  unless $SizeWarning;
Error('Option --size-critical needed!') unless $SizeCritical;
Error('Option --inode-warning needed!')  unless $InodeWarning;
Error('Option --inode-critical needed!') unless $InodeCritical;

my ($crit_msg, $warn_msg, $ok_msg);

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
my $xi3 = new NaElement('volume-space-attributes');
$xi1->child_add($xi3);
$xi3->child_add_string('percentage-size-used','<percentage-size-used>');
my $xi13 = new NaElement('volume-inode-attributes');
$xi1->child_add($xi13);
$xi13->child_add_string('files-total','<files-total>');
$xi13->child_add_string('files-used','<files-used>');
if($Volume){
    $xi2->child_add_string('name',$Volume);
}

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
	
	my $volumes = $output->child_get("attributes-list");
	
	unless($volumes){
	    print "CRITICAL: no volume matching this name\n";
	    exit 2;
	}
	
	my @result = $volumes->children_get();
	
	my $matching_volumes = @result;
	
	if($Volume){
	    if($matching_volumes > 1){
	        print "CRITICAL: more than one volume matching this name";
	        exit 2;
	    }
	}
	
	foreach my $vol (@result){
	
	    my $inode_info = $vol->child_get("volume-inode-attributes");
	    
	    if($inode_info){
	
	        my $inode_used = $inode_info->child_get_int("files-used");
	        my $inode_total = $inode_info->child_get_int("files-total");
	
	        my $inode_percent = sprintf("%.3f", $inode_used/$inode_total*100);
	    
	        my $vol_info = $vol->child_get("volume-id-attributes");
	        my $vol_name = $vol_info->child_get_string("name");
	    
	        my $vol_space = $vol->child_get("volume-space-attributes");
	    
	        my $percent = $vol_space->child_get_int("percentage-size-used");
	
	        if(($percent>=$SizeCritical) || ($inode_percent>=$InodeCritical)){
	            if($crit_msg){
	                $crit_msg .= ", $vol_name (Size: $percent%, Inodes: $inode_percent%)";
	            } else {
	                $crit_msg .= "$vol_name (Size: $percent%, Inodes: $inode_percent%)";
	            }
	            if($perf){ $crit_msg .= "|size=$percent%;$SizeWarning;$SizeCritical inode=$inode_percent%;$InodeWarning;$InodeCritical"; }
	        } elsif (($percent>=$SizeWarning) || ($inode_percent>=$InodeWarning)){
	            if($warn_msg){
	                $warn_msg .= ", $vol_name (Size: $percent%, Inodes: $inode_percent%)";
	            } else {
	                $warn_msg .= "$vol_name (Size: $percent%, Inodes: $inode_percent%)";
	            }
	            if($perf){ $warn_msg .= "|size=$percent%;$SizeWarning;$SizeCritical inode=$inode_percent%;$InodeWarning;$InodeCritical";}
	        } else {
	            if($ok_msg){
	                $ok_msg .= ", $vol_name (Size: $percent%, Inodes: $inode_percent%)";
	            } else {
	                $ok_msg .= "$vol_name (Size: $percent%, Inodes: $inode_percent%)";
	            }
	            if($perf) { $ok_msg .= "|size=$percent%;$SizeWarning;$SizeCritical inode=$inode_percent%;$InodeWarning;$InodeCritical";}
	        }
	    } 
	}
	$next = $output->child_get_string("next-tag");
}

if($crit_msg){
    print "CRITICAL: $crit_msg\n";
    if($warn_msg){
        print "WARNING: $warn_msg\n";
    }
    if($ok_msg){
        print "OK: $ok_msg\n";
    }
    exit 2;
} elsif($warn_msg){
    print "WARNING: $warn_msg\n";
    if($ok_msg){
        print "OK: $ok_msg\n";
    }
    exit 1;
} elsif($ok_msg){
    print "OK: $ok_msg\n";
    exit 0;
} else {
    print "WARNING: no online volume found\n";
    exit 1;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_volume - Check Volume Usage

=head1 SYNOPSIS

check_cdot_aggr.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD --size-warning PERCENT_WARNING \
           --size-critical PERCENT_CRITICAL --inode-warning PERCENT_WARNING \
           --inode-critical PERCENT_CRITICAL (--volume VOLUME) (--perf)

=head1 DESCRIPTION

Checks the Volume Space and Inode Usage of the NetApp System and warns
if warning or critical Thresholds are reached

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to monitor

=item --username USERNAME

The Login Username of the NetApp to monitor

=item --password PASSWORD

The Login Password of the NetApp to monitor

=item --size-warning PERCENT_WARNING

The Warning threshold

=item --size-critical PERCENT_CRITICAL

The Critical threshold

=item --inode-warning PERCENT_WARNING

The Warning threshold

=item --inode-critical PERCENT_CRITICAL

The Critical threshold

=item --volume VOLUME

Optional: The name of the Volume to check

=item --perf

Flag for performance data output

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 on Unknown Error
2 if Critical Threshold has been reached
1 if Warning Threshold has been reached or any problem occured
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stefan Grosser <sgr at firstframe.net>
