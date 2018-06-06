#!/usr/bin/perl

# nagios: -epn
# --
# check_cdot_interfaces.pl - Check FCP interfaces
# Copyright (C) 2017 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use 5.6.1; 
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

my $errors = 0;
my $msg;

my $stats_output = $s->invoke("fcp-adapter-stats-get-iter");

if ($stats_output->results_errno != 0) {
    my $r = $stats_output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $lifs = $stats_output->child_get("attributes-list");

if($lifs){

    my @adapters = $lifs->children_get("fcp-adapter-stats-info");

    foreach my $adapter (@adapters){

        my $adapter_name = $adapter->child_get_string("adapter");
        my $node = $adapter->child_get_string("node");

        my $adapter_reset = $adapter->child_get_string("adapter-resets");
        my $crc_errors = $adapter->child_get_string("crc-errors");
        my $discarded_frames = $adapter->child_get_string("discarded-frames");
        my $invalid_xmit_words = $adapter->child_get_string("invalid-xmit-words");
        my $link_breaks = $adapter->child_get_string("link-breaks");
        my $lip_resets = $adapter->child_get_string("lip-resets");
        my $protocol_errors = $adapter->child_get_string("protocol-errors");
        my $scsi_requests_dropped = $adapter->child_get_string("scsi-requests-dropped");

        my $total_errors = $adapter_reset+$crc_errors+$discarded_frames+$invalid_xmit_words+$link_breaks+$lip_resets+$protocol_errors+$scsi_requests_dropped;

        if($total_errors > 0){

            $errors++;

            $msg .= "$node: $adapter_name has errors\n";
            $msg .= "adapter_reset: $adapter_reset\n";
            $msg .= "crc_errors: $crc_errors\n";
            $msg .= "discarded_frames: $discarded_frames\n";
            $msg .= "invalid_xmit_words: $invalid_xmit_words\n";
            $msg .= "link_breaks: $link_breaks\n";
            $msg .= "lip_resets: $lip_resets\n";
            $msg .= "protocol_errors: $protocol_errors\n";
            $msg .= "scsi_requests_dropped: $scsi_requests_dropped\n\n";

        }
    }
}

if($errors > 0){
    print $msg;
    exit 2;
} else {
    print "OK - no FC interface errors\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_cdot_fcp - Check fcp interfaces

=head1 SYNOPSIS

check_cdot_fcp.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD

=head1 DESCRIPTION

Checks if all fcp interface have CRC errors

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to monitor (Cluster or Node MGMT)

=item --username USERNAME

The Login Username of the NetApp to monitor

=item --password PASSWORD

The Login Password of the NetApp to monitor

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 on Unknown Error
2 if any link is down
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
