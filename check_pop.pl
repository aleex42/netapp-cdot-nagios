#!/usr/bin/perl

use lib "/usr/lib/netapp-manageability-sdk/lib/perl/NetApp";
use NaServer;
use NaElement;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

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

my @old_snapshots;
my $now = time;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user( $Username, $Password );

my $snap_iterator = NaElement->new("snapshot-get-iter");
my $tag_elem = NaElement->new("tag");
$snap_iterator->child_add($tag_elem);

my $xi = new NaElement('desired-attributes');
$snap_iterator->child_add($xi);
my $xi1 = new NaElement('snapshot-info');
$xi->child_add($xi1);
$xi1->child_add_string('name','name');
$xi1->child_add_string('volume','vol_winzone_data_nfs_cifs_pop');
$xi1->child_add_string('access-time','access-time');

my ($hourly, $nightly, $weekly);

my $next = "";

while(defined($next)){
        unless($next eq ""){
            $tag_elem->set_content($next);    
        }

        $snap_iterator->child_add_string("max-records", 1000);
        my $snap_output = $s->invoke_elem($snap_iterator);

        if ($snap_output->results_errno != 0) {
            my $r = $snap_output->results_reason();
            print "UNKNOWN: $r\n";
            exit 3;
        }

        my @snapshots = $snap_output->child_get("attributes-list")->children_get();

        unless(@snapshots){
            print "OK - No snapshots\n";
            exit 0;
        }

        foreach my $snap (@snapshots){

            my $vol_name = $snap->child_get_string("volume");

            if($vol_name eq "vol_winzone_data_nfs_cifs_pop"){

                my $snap_name  = $snap->child_get_string("name");

                if($snap_name =~ m/hourly/){
                    $hourly++;
                } elsif($snap_name =~ m/nightly/){
                    $nightly++;
                } elsif($snap_name =~ m/weekly/){
                    $weekly++;
                }
            }
        }
        $next = $snap_output->child_get_string("next-tag");
}

if(($hourly >= 12) && ($nightly >= 6) && ($weekly >= 2)){
    print "OK - all snapshots exist\n";
    exit 0;
} else {
    print "Only $hourly hourly, $nightly nightly and $weekly weekly snapshots\n";
    exit 2;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_snapshots - Check if there are old Snapshots

=head1 SYNOPSIS

check_cdot_snapshots.pl --hostname HOSTNAME \
    --username USERNAME --password PASSWORD

=head1 DESCRIPTION

Checks if old ( > 90 days ) Snapshots exist

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
1 if Warning Threshold (90 days) has been reached
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
 Stelios Gikas <sgikas at demokrit.de>
