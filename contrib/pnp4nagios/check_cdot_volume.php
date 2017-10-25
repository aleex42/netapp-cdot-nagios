<?php
#
# check_cdot_volume.php - based on check_netappfileri_vol.php from 
# https://github.com/wAmpIre/check_netappfiler
#
# RRDtool Options
$opt[1] = "--vertical-label Bytes -l 0 -r --title \"Volume  $hostname / $servicedesc\" --height=200 -b 1024 ";
#
#
# Graphen Definitions
$def[1]  = "DEF:dataused=$rrdfile:$DS[1]:AVERAGE "; 
$def[1] .= "DEF:inodeused=$rrdfile:$DS[2]:AVERAGE ";
$def[1] .= "DEF:snapused=$rrdfile:$DS[3]:AVERAGE "; 
$def[1] .= "DEF:datatotal=$rrdfile:$DS[4]:AVERAGE "; 
$def[1] .= "DEF:snapsize=$rrdfile:$DS[5]:AVERAGE "; 

// $def[1] .= "CDEF:snapsnap=snap,snapsize,GT,snapsize,snap,IF ";
$def[1] .= "CDEF:snapfree=snapused,snapsize,GT,0,snapsize,snapused,-,IF ";
$def[1] .= "CDEF:snapover=snapused,snapsize,GT,snapused,snapsize,-,0,IF ";
$def[1] .= "CDEF:datafree=datatotal,dataused,- ";

$def[1] .= "CDEF:warn=dataused,0,*,$WARN[1],+ ";
$def[1] .= "CDEF:crit=dataused,0,*,$CRIT[1],+ ";

$def[1] .= "AREA:dataused#aaaaaa:\"Data\: Used space\" "; 
$def[1] .= "GPRINT:dataused:LAST:\"%6.2lf%S\\n\" ";
$def[1] .= "AREA:datafree#00ff00:\"Data\: Free space\":STACK ";
$def[1] .= "GPRINT:datafree:LAST:\"%6.2lf%S\\n\" ";
$def[1] .= "AREA:snapover#aa0000:\"Snap\: Over resv.\":STACK ";
$def[1] .= "GPRINT:snapover:LAST:\"%6.2lf%S\\n\" ";
$def[1] .= "AREA:snapfree#00ffff:\"Snap\: Free space\":STACK ";
$def[1] .= "GPRINT:snapfree:LAST:\"%6.2lf%S\\n\" ";
$def[1] .= "AREA:snapused#0000cc:\"Snap\: Used space\":STACK ";
$def[1] .= "GPRINT:snapused:LAST:\"%6.2lf%S\\n\" ";

$def[1] .= "LINE1:datatotal#000000 "; 

$def[1] .= "LINE2:datafree#ffffff:\"Available space \": ";
$def[1] .= "GPRINT:datafree:LAST:\"%6.2lf%S\\n\" ";

if ($WARN[1] != "") {
	$def[1] .= "LINE1:warn#ffff00:\"Warning at      \" ";
	$def[1] .= "GPRINT:warn:LAST:\"%6.2lf%S\\n\" ";
}
if ($CRIT[1] != "") {
	$def[1] .= "LINE1:crit#ff0000:\"Critical at     \" ";
	$def[1] .= "GPRINT:crit:LAST:\"%6.2lf%S\\n\" ";
}

?>
