#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_diff_snapmirror - Checks Volumes without SnapMirror
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
    'exclude=s'  => \my @excludelistarray,
    'regexp'     => \my $regexp,	
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

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $snap_iterator = NaElement->new("snapmirror-get-destination-iter");
my $tag_elem = NaElement->new("tag");
$snap_iterator->child_add($tag_elem);

my $next = "";
my @snapmirror_sources;
my @missing_snapmirror;
my @auto_excluded_volumes;
my @manually_excluded_volumes;

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
                print "OK - Nothing to check\n";
                exit 0;
        }
	
        my @snapmirrors = $snap_output->child_get("attributes-list")->children_get();

	foreach my $snap (@snapmirrors){
        my $source = $snap->child_get_string("source-location");
        push(@snapmirror_sources,$source);
	}
	$next = $snap_output->child_get_string("next-tag");
}

my $iterator = NaElement->new("volume-get-iter");
$tag_elem = NaElement->new("tag");
$iterator->child_add($tag_elem);

my $xi = new NaElement('desired-attributes');
$iterator->child_add($xi);
my $xi1 = new NaElement('volume-attributes');
$xi->child_add($xi1);
my $xi2 = new NaElement('volume-id-attributes');
$xi1->child_add($xi2);
$xi2->child_add_string('name','<name>');
$xi2->child_add_string('type','<type>');
my $xi4 = new NaElement('query');
$iterator->child_add($xi4);
my $xi5 = new NaElement('volume-attributes');
$xi4->child_add($xi5);
$next = "";

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
    my @result = $volumes->children_get();

    foreach my $vol (@result){

        my $id = $vol->child_get("volume-id-attributes");

        my $vol_name = $id->child_get_string("name");
        my $type = $id->child_get_string("type");

        my $vserver = $id->child_get_string("owning-vserver-name");
        my $location = "$vserver:$vol_name";

        # notes:
        #  ^MDV_CRS : CDOT Meta Data
        if (($vol_name =~ m/^MDV_CRS|vol0|_root$/) || ($type eq "dp")){
            push(@auto_excluded_volumes,$location."\n");
            next;
        }

        if (exists $Excludelist{$vol_name}) {
            push(@manually_excluded_volumes,$location."\n");
            next;
        }
		
        if ($regexp and $excludeliststr) {
            if ($vol_name =~ m/$excludeliststr/) {
                push(@manually_excluded_volumes,$location."\n");
                next;
            }
        }

        my $result = grep (/$location/,@snapmirror_sources);

        unless($result){
            push(@missing_snapmirror,$location."\n");
        }
    }
    $next = $output->child_get_string("next-tag");
}

if (@missing_snapmirror) {
    print @missing_snapmirror . " volume(s) without snapmirror|\n";
    print "Volume(s) without snapmirror:\n";
    print "@missing_snapmirror\n";
    print "Manually excluded volume(s):\n";
    print "@manually_excluded_volumes\n";
    print "Auto excluded volume(s):\n";
    print "@auto_excluded_volumes\n";
    exit 1;
}
else {
    print "All volumes are snapmirrored|\n";
    print "Manually excluded volume(s):\n";
    print "@manually_excluded_volumes\n";
    print "Auto excluded volume(s):\n";
    print "@auto_excluded_volumes\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_diff_snapmirror - Checks SnapMirror Configuration

=head1 SYNOPSIS

check_cdot_snapmirror.pl --hostname HOSTNAME --username USERNAME --password PASSWORD
           [--exclude VOLUME-NAME] [--regexp] [--verbose]

=head1 DESCRIPTION

Checks that all the volumes have a SnapMirror configuration

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to monitor

=item --username USERNAME

The Login Username of the NetApp to monitor

=item --password PASSWORD

The Login Password of the NetApp to monitor

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
