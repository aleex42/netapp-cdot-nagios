#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_snapmirror - Checks SnapMirror Healthnes
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
    'lag=i'      => \my $LagOpt,
    'volume=s'   => \my $VolumeName,
    'vserver=s'  => \my $VServer,
    'exclude=s'  => \my @excludelistarray,
    'regexp'     => \my $regexp,
    'v|verbose'  => \my $verbose,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

my %Excludelist;
@Excludelist{@excludelistarray}=();
my $excludeliststr = join "|", @excludelistarray;

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;
$LagOpt = 3600 * 28 unless $LagOpt; # 1 day 4 hours

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $snap_iterator = NaElement->new("snapmirror-get-iter");
my $tag_elem = NaElement->new("tag");
$snap_iterator->child_add($tag_elem);

my $query_elem;
my $sminfo_elem;
if(defined($VolumeName) || defined($VServer)) {
	$query_elem = NaElement->new("query");
        $snap_iterator->child_add($query_elem);
	$sminfo_elem = NaElement->new("snapmirror-info");
	$query_elem->child_add($sminfo_elem);
	if(defined($VolumeName)) {
		$sminfo_elem->child_add_string("destination-volume", $VolumeName);
	}
	if(defined($VServer)) {
		$sminfo_elem->child_add_string("destination-vserver", $VServer);
	}
}

my $next = "";
my $snapmirror_failed = 0;
my $snapmirror_ok = 0;
my %failed_names;
my @excluded_volumes;

while(defined($next)){
	unless($next eq ""){
		$tag_elem->set_content($next);    
	}

	$snap_iterator->child_add_string("max-records", 100);
	my $snap_output = $s->invoke_elem($snap_iterator);

	if ($snap_output->results_errno != 0) {
		my $r = $snap_output->results_reason();
		print "UNKNOWN: $r\n";
		exit 3;
	}

	my $num_records = $snap_output->child_get_string("num-records");

	if($num_records eq 0){
        last;
	}

	my @snapmirrors = $snap_output->child_get("attributes-list")->children_get();

	foreach my $snap (@snapmirrors){

		my $status = $snap->child_get_string("relationship-status");
		my $healthy = $snap->child_get_string("is-healthy");
		my $lag = $snap->child_get_string("lag-time");
		my $dest_vol = $snap->child_get_string("destination-volume");
		my $current_transfer = $snap->child_get_string("current-transfer-type");
                if ($verbose) {
                   print "[DEBUG] dest_vol=$dest_vol,\t status=$status,\t healthy=$healthy,\t lag=$lag\n";
                }
                if (exists $Excludelist{$dest_vol}) {
                   push(@excluded_volumes,$dest_vol."\n");
                   next;
                }
                if ($regexp and $excludeliststr) {
                   if ($dest_vol =~ m/$excludeliststr/) {
                     push(@excluded_volumes,$dest_vol."\n");
                     next;
                   }
                }
		if($healthy eq "false"){
                   if ($verbose) {
                      print "[DEBUG] ".Dumper($snap);
                   }
                   if(! $current_transfer){
    			$failed_names{$dest_vol} = [ $healthy, $lag ];
    			$snapmirror_failed++;
                   } elsif (($status eq "transferring") || ($status eq "finalizing")){
    			$snapmirror_ok++;
    		   }
                } else {
                   $snapmirror_ok++;
                }

                if(defined($lag) && ($lag >= $LagOpt)){
                    if ($verbose) {
                      print "[DEBUG] ".Dumper($snap);
                    }
                    unless(($failed_names{$dest_vol}) || ($status eq "transferring") || ($status eq "finalizing")){
                        $failed_names{$dest_vol} = [ $healthy, $lag ];
                        $snapmirror_failed++;
                    }
                }

	}
	$next = $snap_output->child_get_string("next-tag");
}


if ($snapmirror_failed) {
	print "CRITICAL: $snapmirror_failed snapmirror(s) failed - $snapmirror_ok snapmirror(s) ok\n";
	print "Failing snapmirror(s):\n";
	printf ("%-*s%*s%*s\n", 50, "Name", 10, "Healthy", 10, "Delay");
	for my $vol ( keys %failed_names ) {
		my $health_lag = $failed_names{$vol};
		my @health_lag_value = @{ $health_lag };
		$health_lag_value[1] = "--- " unless $health_lag_value[1];
		printf ("%-*s%*s%*s\n", 50, $vol, 10, $health_lag_value[0], 10, $health_lag_value[1] . "s");
	}
        print "\nExcluded volume(s):\n";
        print "@excluded_volumes\n";
	exit 2;
} else {
	print "OK: $snapmirror_ok snapmirror(s) ok\n";
        print "\nExcluded volume(s):\n";
        print "@excluded_volumes\n";
	exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_snapmirror - Checks SnapMirror Healthness

=head1 SYNOPSIS

check_cdot_snapmirror.pl --hostname HOSTNAME --username USERNAME
           --password PASSWORD [--lag DELAY-SECONDS]
           [--volume VOLUME-NAME] [--vserver VSERVER-NAME] 
           [--exclude VOLUME-NAME] [--regexp] [--verbose]

=head1 DESCRIPTION

Checks the Healthnes of the SnapMirror and wheather every snapshot has a lag lower than one day

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to monitor

=item --username USERNAME

The Login Username of the NetApp to monitor

=item --password PASSWORD

The Login Password of the NetApp to monitor

=item --lag DELAY-SECONDS

Snapmirror delay in Seconds. Default 28h

=item --volume VOLUME-NAME

Name of the destination volume to be checked. If not specified, check all volumes.

=item --vserver VSERVER-NAME

Name of the destination vserver to be checked. If not specificed, search only the base server.

=item --exclude

Optional: The name of a volume that has to be excluded from the checks (multiple exclude item for multiple volumes)

=item --regexp

Optional: Enable regexp matching for the exclusion list

=item -v | --verbose

Enable verbose mode

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 if timeout occured
2 if there is an error in the SnapMirror
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stelios Gikas <sgikas at demokrit.de>
