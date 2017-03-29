#!/usr/bin/perl

# nagios: -epn
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

use lib "/usr/lib/netapp-manageability-sdk/lib/perl/NetApp";
use NaServer;
use NaElement;
use Getopt::Long qw(:config no_ignore_case);

GetOptions(
    'H|hostname=s' => \my $Hostname,
    'u|username=s' => \my $Username,
    'p|password=s' => \my $Password,
    'w|size-warning=i'  => \my $SizeWarning,
    'c|size-critical=i' => \my $SizeCritical,
    'inode-warning=i'  => \my $InodeWarning,
    'inode-critical=i' => \my $InodeCritical,
    'snap-warning=i' => \my $SnapWarning,
    'snap-critical=i' => \my $SnapCritical,
    'P|perf'     => \my $perf,
    'V|volume=s'   => \my $Volume,
    'vserver=s'  => \my $Vserver,
    'exclude=s'	 =>	\my @excludelistarray,
    'h|help'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
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
Error('Option --size-warning needed!')  unless $SizeWarning;
Error('Option --size-critical needed!') unless $SizeCritical;

# Set some conservative default thresholds for the more
# esoteric metrics
$InodeWarning = 65 unless $InodeWarning;
$InodeCritical = 85 unless $InodeCritical;
$SnapWarning = 75 unless $SnapWarning;
$SnapCritical = 90 unless $SnapCritical;

my ($crit_msg, $warn_msg, $ok_msg);
# Store all perf data points for output at end
my %perfdata=();

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
$xi3->child_add_string('size-used', '<size-used>');
$xi3->child_add_string('size-total', '<size-total>');
$xi3->child_add_string('snapshot-reserve-size', '<snapshot-reserve-size>');
$xi3->child_add_string('size-used-by-snapshots', '<size-used-by-snapshots>');
$xi3->child_add_string('percentage-snapshot-reserve-used', '<percentage-snapshot-reserve-used>');
my $xi13 = new NaElement('volume-inode-attributes');
$xi1->child_add($xi13);
$xi13->child_add_string('files-total','<files-total>');
$xi13->child_add_string('files-used','<files-used>');
my $xi4 = new NaElement('query');
$iterator->child_add($xi4);
my $xi5 = new NaElement('volume-attributes');
$xi4->child_add($xi5);
if($Volume){
    my $xi6 = new NaElement('volume-id-attributes');
    $xi5->child_add($xi6);
    $xi6->child_add_string('name',$Volume);
}
my $next = "";

my (@crit_msg, @warn_msg, @ok_msg);

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
	#print Dumper $volumes;
	
	unless($volumes){
	    print "CRITICAL: no volume matching this name\n";
	    exit 2;
	}
	
	my @result = $volumes->children_get();
	my $matching_volumes = @result;

	if($Volume && !$Vserver){
	    if($matching_volumes > 1){
	        print "CRITICAL: more than one volume matching this name\n";
	        exit 2;
	    }
	}
	
	foreach my $vol (@result){

	    my $vol_info = $vol->child_get("volume-id-attributes");
	    my $vserver_name = $vol_info->child_get_string("owning-vserver-name");
	    my $vol_name = "$vserver_name/" . $vol_info->child_get_string("name");

	    if($Volume) {
	        if($vserver_name ne $Vserver) {
	            next;
	        }
	    }
	
	    my $inode_info = $vol->child_get("volume-inode-attributes");
	    
	    if($inode_info){
	
	        my $inode_used = $inode_info->child_get_int("files-used");
	        my $inode_total = $inode_info->child_get_int("files-total");
	
	        my $inode_percent = sprintf("%.3f", $inode_used/$inode_total*100);
	    
	        next if exists $Excludelist{$vol_name};
	    
	        my $vol_space = $vol->child_get("volume-space-attributes");
	        my $percent = $vol_space->child_get_int("percentage-size-used");
		my $snaptotal = $vol_space->child_get_int("snapshot-reserve-size");
		my $snapused = $vol_space->child_get_int("size-used-by-snapshots");
		my $snapusedpct = $vol_space->child_get_int("percentage-snapshot-reserve-used");
	
		$perfdata{$vol_name}{'byte_used'}=$vol_space->child_get_int("size-used");
		$perfdata{$vol_name}{'byte_total'}=$vol_space->child_get_int("size-total");
		$perfdata{$vol_name}{'inode_used'}=$inode_used;
		$perfdata{$vol_name}{'inode_total'}=$inode_total;
		$perfdata{$vol_name}{'snap_total'}=$snaptotal;
		$perfdata{$vol_name}{'snap_used'}=$snapused;

	        if(($percent>=$SizeCritical) || ($inode_percent>=$InodeCritical)){
		    push (@crit_msg, "$vol_name (Size: $percent%, Inodes: $inode_percent%)" );
	        } elsif (($percent>=$SizeWarning) || ($inode_percent>=$InodeWarning)){
		    push (@warn_msg, "$vol_name (Size: $percent%, Inodes: $inode_percent%)" );
	        } else {
		    push (@ok_msg, "$vol_name (Size: $percent%, Inodes: $inode_percent%)" );
	        }
		if($snapusedpct >= $SnapCritical) {
		    push (@crit_msg, "$vol_name has used $snapusedpct% of snapshot reserve.");
		} elsif ($snapusedpct >= $SnapWarning) {
		    push (@warn_msg, "$vol_name has used $snapusedpct% of snapshot reserve.");
		}
	    } 
	}
	$next = $output->child_get_string("next-tag");
}

# Build perf data string for output
my $perfdatastr="";
foreach my $vol ( keys(%perfdata) ) {
    # DS[1] - Data space used
    $perfdatastr.=sprintf(" %s_space_used=%dBytes;%d;%d;%d;%d", $vol, $perfdata{$vol}{'byte_used'},
	$SizeWarning*$perfdata{$vol}{'byte_total'}/100, $SizeCritical*$perfdata{$vol}{'byte_total'}/100,
	0, $perfdata{$vol}{'byte_total'} );
    # DS[2] - Inodes used
    $perfdatastr.=sprintf(" %s_inode_used=%d;%d;%d;%d;%d", $vol, $perfdata{$vol}{'inode_used'},
	$InodeWarning*$perfdata{$vol}{'inode_total'}/100, $InodeCritical*$perfdata{$vol}{'inode_total'}/100,
	0, $perfdata{$vol}{'inode_total'} );
    # DS[3] - Snapshot space used
    $perfdatastr.=sprintf(" %s_snap_used=%dBytes;;;%d;%d", $vol, $perfdata{$vol}{'snap_used'},
	0, $perfdata{$vol}{'snap_total'} );
    # DS[4] - Data total space
    $perfdatastr.=sprintf(" %s_data_total=%dBytes", $vol, $perfdata{$vol}{'byte_total'} );
    # DS[5] - Snap total space
    $perfdatastr.=sprintf(" %s_snap_total=%dBytes", $vol, $perfdata{$vol}{'snap_total'} );

}

if(scalar(@crit_msg) ){
    print "CRITICAL: ";
    print join (" ", @crit_msg, @warn_msg, @ok_msg);
    print "|$perfdatastr\n";
    exit 2;
} elsif(scalar(@warn_msg) ){
    print "WARNING: ";
    print join (" ", @crit_msg, @warn_msg, @ok_msg);
    print "|$perfdatastr\n";
    exit 1;
} elsif(scalar(@ok_msg) ){
    print "OK: ";
    print join (" ", @crit_msg, @warn_msg, @ok_msg);
    print "|$perfdatastr\n";
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

check_cdot_aggr.pl -H HOSTNAME -u USERNAME -p PASSWORD \
           -w PERCENT_WARNING -c PERCENT_CRITICAL \
	   --snap-warning PERCENT_WARNING \
	   --snap-critical PERCENT_CRITICAL \
	   --inode-warning PERCENT_WARNING \
           --inode-critical PERCENT_CRITICAL [-V VOLUME] [-P]

=head1 DESCRIPTION

Checks the Volume Space and Inode Usage of the NetApp System and warns
if warning or critical Thresholds are reached

=head1 OPTIONS

=over 4

=item -H | --hostname FQDN

The Hostname of the NetApp to monitor

=item -u | --username USERNAME

The Login Username of the NetApp to monitor

=item -p | --password PASSWORD

The Login Password of the NetApp to monitor

=item --size-warning PERCENT_WARNING

The Warning threshold for data space usage.

=item --size-critical PERCENT_CRITICAL

The Critical threshold for data space usage.

=item --inode-warning PERCENT_WARNING

The Warning threshold for inodes (files). Defaults to 65% if not given.

=item --inode-critical PERCENT_CRITICAL

The Critical threshold for inodes (files). Defaults to 85% if not given.

=item --snap-warning PERCENT_WARNING

The Warning threshold for snapshot space usage. Defaults to 75%.

=item --snap-critical PERCENT_CRITICAL

The Critical threshold for snapshot space usage. Defaults to 90%.

=item -V | --volume VOLUME

Optional: The name of the Volume to check

=item -P --perf

Flag for performance data output

=item --exclude

Optional: The name of a volume that has to be excluded from the checks (multiple exclude item for multiple volumes)

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
