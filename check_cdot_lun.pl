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
use Getopt::Long;

GetOptions(
    'hostname=s' => \my $Hostname,
    'username=s' => \my $Username,
    'password=s' => \my $Password,
    'size-warning=i'  => \my $SizeWarning,
    'size-critical=i' => \my $SizeCritical,
    'volume=s'   => \my $Volume,
    'vserver=s'	 => \my $Vserver,
    'perf'     => \my $perf,
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

my ($crit_msg, $warn_msg, $ok_msg);

my $s = new NaServer($Hostname, 1 , 3 );
$s->set_transport_type('HTTPS');
$s->set_style('LOGIN');
$s->set_admin_user($Username, $Password);


my $iterator = new NaElement('lun-get-iter');
my $tag_elem = NaElement->new("tag");
$iterator->child_add($tag_elem);

my $xi = new NaElement('desired-attributes');
$iterator->child_add($xi);
my $xi1 = new NaElement('lun-info');
$xi->child_add($xi1);
$xi1->child_add_string('online','<online>');
$xi1->child_add_string('path','<path>');
$xi1->child_add_string('size','<size>');
$xi1->child_add_string('size-used','<size-used>');
$xi1->child_add_string('state','<state>');
$xi1->child_add_string('volume','<volume>');
my $xi2 = new NaElement('query');
$iterator->child_add($xi2);
my $xi3 = new NaElement('lun-info');
$xi2->child_add($xi3);
if($Volume){
	$xi3->child_add_string('volume',$Volume);
}
if($Vserver){
	$xi3->child_add_string('vserver',$Vserver);
}
my $next = '';

while(defined($next)){
	unless($next eq ""){
		$tag_elem->set_content($next);
	}

	$iterator->child_add_string('max-records',100);
	my $output = $s->invoke_elem($iterator);
	if ($output->results_errno != 0) {
	    my $r = $output->results_reason();
	    print "UNKNOWN: $r\n";
	    exit 3;
	}

	my $luns_all = $output->child_get("attributes-list");
	unless($output->child_get_int('num-records') != 0) {
		print "CRITICAL: no volume matching this name\n"; 
		exit 2;
	}

	my @result = $luns_all->children_get();

	my $matching_volumes = @result;

	foreach my $lun_info (@result){

		if ($lun_info) {
			my $lun_path = $lun_info->child_get_string("path");

			my $space_used = $lun_info->child_get_int("size-used");
			my $space_total = $lun_info->child_get_int("size");
			
			my $space_percent = sprintf ("%.3f", $space_used/$space_total*100);

			$space_used = $space_used / 1048576;
			$space_total = $space_total / 1048576;

			if($space_percent>=$SizeCritical){
				if($crit_msg){
					$crit_msg .= ", $lun_path (Usage: $space_used/$space_total MB; $space_percent%)";
				} else {
					$crit_msg .= "$lun_path (Usage: $space_used/$space_total MB; $space_percent%)";
				}
				if($perf){ $crit_msg .= "|'$lun_path'=$space_percent%;$SizeWarning;$SizeCritical "; }
			} elsif ($space_percent>=$SizeWarning){
				if($warn_msg){
					$warn_msg .= ", $lun_path (Usage: $space_used/$space_total MB; $space_percent%)";
				} else {
					$warn_msg .= "$lun_path (Usage: $space_used/$space_total MB; $space_percent%)";
				}
				if($perf){ $warn_msg .= "|'$lun_path'=$space_percent%;$SizeWarning;$SizeCritical ";}
			} else {
				if($ok_msg){
					$ok_msg .= ", $lun_path (Usage: $space_used/$space_total MB; $space_percent%)";
				} else {
					$ok_msg .= "$lun_path (Usage: $space_used/$space_total MB; $space_percent%)";
				}
				if($perf) { $ok_msg .= "|'$lun_path'=$space_percent%;$SizeWarning;$SizeCritical ";}
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

check_cdot_lun - Check Lun Usage

=head1 SYNOPSIS

check_cdot_lun.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD --size-warning PERCENT_WARNING \
           --size-critical PERCENT_CRITICAL (--volume VOLUME) (--perf)

=head1 DESCRIPTION

Checks the lUN Space usage of the NetApp System and warns
if warning or critical Thresholds are reached

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to monitor (Cluster or Node MGMT)

=item --username USERNAME

The Login Username of the NetApp to monitor

=item --password PASSWORD

The Login Password of the NetApp to monitor

=item --size-warning PERCENT_WARNING

The Warning threshold

=item --size-critical PERCENT_CRITICAL

The Critical threshold

=item --volume VOLUME

Optional: The name of the Volume where the Luns that need to be checked are located

=item --vserver VSERVER

Optional: The name of the Vserver where the Luns that need to be checked are located

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

 Giorgio Maggiolo <giorgio at maggiolo dot net>
