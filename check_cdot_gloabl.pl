#!/usr/bin/perl

# check_cdot_global
# usage: ./check_cdot_global hostname username password $PLUGIN (where PLUGIN is 'powersupply', 'fans', 'nvram', 'temp' or 'health')
# Alexander Krogloth <git at krogloth.de>

use lib "/usr/lib/netapp-manageability-sdk-5.1/lib/perl/NetApp";
use NaServer;
use NaElement;
use strict;
use warnings;
use 5.10.0;

my $s = NaServer->new ($ARGV[0], 1, 3);

$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user($ARGV[1], $ARGV[2]);

my $output = $s->invoke("system-node-get-iter");

if ($output->results_errno != 0) {
	my $r = $output->results_reason();
	print "UNKNOWN - $r\n";
	exit 3;
}

my $plugin;

if($ARGV[3]){
	$plugin = $ARGV[3];
} else {
        print "Plugin not specified. Usage: check_cnetapp HOST USER PW PLUGIN - possible Plugins: 'power', 'fan', 'nvram', 'temp', 'health'\n";
        exit 2;
}

if(($plugin ne "power") && ($plugin ne "fan") && ($plugin ne "nvram") && ($plugin ne "temp") && ($plugin ne "health")){
	print "Plugin $plugin not known - possible Plugins: 'power', 'fan', 'nvram', 'temp', 'health'\n";
	exit 2;
}

my $heads = $output->child_get("attributes-list");
my @result = $heads->children_get();

my $head;
my $sum_failed_power = 0;
my $sum_failed_fan = 0;
my $sum_failed_nvram = 0;
my $sum_failed_temp = 0;
my $sum_failed_health = 0;

given($plugin){
	
	when("power"){

		foreach $head (@result){

			my $failed_power_count = $head->child_get_string("env-failed-power-supply-count");
			if($failed_power_count > 0){
				$sum_failed_power += 1;
			}
		}

		if($sum_failed_power > 0){
			print "$sum_failed_power failed power supply(s)\n";
			exit 2;
		} else {
			print "No failed power supplys\n";
			exit 0;
		}
	}

	when("fan"){
                foreach $head (@result){

                        my $failed_fan_count = $head->child_get_string("env-failed-fan-count");
                        if($failed_fan_count > 0){
                                $sum_failed_fan += 1;
                        }
                }

                if($sum_failed_fan > 0){
                        print "$sum_failed_fan failed fan(s)\n";
                        exit 2;
                } else {
                        print "No failed fans\n";
                        exit 0;
                }
	}

	when("nvram"){
                foreach $head (@result){
			
			my $nvram_status = $head->child_get_string("nvram-battery-status");
			if($nvram_status ne "battery_ok"){
				$sum_failed_nvram += 1;
			}

		}

                if($sum_failed_nvram > 0){
                        print "$sum_failed_nvram failed nvram(s)\n";
                        exit 2;
                } else {
                        print "No failed nvram\n";
                        exit 0;
                }
	}

	when("temp"){
                foreach $head (@result){

			my $temp_status = $head->child_get_string("env-over-temperature");
                        if($temp_status ne "false"){
                                $sum_failed_temp += 1;
                        }

                }

                if($sum_failed_temp > 0){
                        print "Temperature Overheating\n";
                        exit 2;
                } else {
                        print "Temperature OK\n";
                        exit 0;
                }
	}

	when("health"){
                foreach $head (@result){

			my $health_status = $head->child_get_string("is-node-healthy");
                        if($health_status ne "true"){
                                $sum_failed_health += 1;
                        }

                }

                if($sum_failed_health > 0){
                        print "Health Status Critical\n";
                        exit 2;
                } else {
                        print "Health Status OK\n";
                        exit 0;
                }
	}
}




