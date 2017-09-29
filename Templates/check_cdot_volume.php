<?php
#
# check_cdot_volume.php - based on check_netappfileri_vol.php from 
# https://github.com/wAmpIre/check_netappfiler
#
# RRDtool Options
$opt[1] = "--vertical-label Bytes -l 0 -r --title \"Volume  $hostname / $servicedesc\" --height=200 -b 1024 ";
#
#
# Graph Definitions
$def[1]  = rrd::def("dataused", $RRDFILE[1], $DS[1], "AVERAGE");
$def[1] .= rrd::def("inodeused",$RRDFILE[2], $DS[2], "AVERAGE");
$def[1] .= rrd::def("snapused", $RRDFILE[3], $DS[3], "AVERAGE");
$def[1] .= rrd::def("datatotal",$RRDFILE[4], $DS[4], "AVERAGE");
$def[1] .= rrd::def("snapsize", $RRDFILE[5], $DS[5], "AVERAGE");

$def[1] .= "CDEF:snapover=snapused,snapsize,GT,snapused,snapsize,-,0,IF ";
$def[1] .= "CDEF:snapfree=snapused,snapsize,GT,0,snapsize,snapused,-,IF ";
$def[1] .= "CDEF:snapwoover=snapused,snapover,- ";

$def[1] .= "CDEF:datausedpct=dataused,datatotal,/,100,* ";
$def[1] .= "CDEF:datausedwoover=dataused,snapover,- ";
$def[1] .= "CDEF:datafree=datatotal,datausedwoover,-,snapover,- ";

$def[1] .= "CDEF:warn=dataused,0,*,$WARN[1],+ ";
$def[1] .= "CDEF:crit=dataused,0,*,$CRIT[1],+ ";

$def[1] .= "AREA:datausedwoover#aaaaaa:\"Data\: Used space\" ";
$def[1] .= "GPRINT:datausedwoover:LAST:\"%6.2lf%S\\n\" ";
$def[1] .= "AREA:datafree#00ff00:\"Data\: Free space\":STACK ";
$def[1] .= "GPRINT:datafree:LAST:\"%6.2lf%S\\n\" ";
$def[1] .= "AREA:snapover#aa0000:\"Snap\: Over resv.\":STACK ";
$def[1] .= "GPRINT:snapover:LAST:\"%6.2lf%S\\n\" ";
$def[1] .= "AREA:snapfree#00ffff:\"Snap\: Free space\":STACK ";
$def[1] .= "GPRINT:snapfree:LAST:\"%6.2lf%S\\n\" ";
$def[1] .= "AREA:snapwoover#0000cc:\"Snap\: Used space\":STACK ";
$def[1] .= "GPRINT:snapwoover:LAST:\"%6.2lf%S\\n\" ";

$def[1] .= "LINE1:datatotal#000000 "; 

$def[1] .= "LINE2:datafree#ffffff:\"Available space \": ";
$def[1] .= "GPRINT:datafree:LAST:\"%6.2lf%S\\n\" ";

$def[1] .= "COMMENT:\" \\n\" ";
$def[1] .= "GPRINT:datatotal:LAST:\"Configured visible data space\: %6.2lf%S\\n\" ";
$def[1] .= "GPRINT:snapsize:LAST:\"Configured snapshot resv.\:     %6.2lf%S\\n\" ";
$def[1] .= "COMMENT:\" \\n\" ";
$def[1] .= "GPRINT:dataused:LAST:\"Data used space incl. snapshot over reserv.\: %6.2lf%S\" ";
$def[1] .= "GPRINT:datausedpct:LAST:\"(%6.2lf%%)\\n\" ";
if ($WARN[1] != "") {
	$def[1] .= "LINE1:warn#ffff00:\"Warning at      \" ";
	$def[1] .= "GPRINT:warn:LAST:\"%6.2lf%S\\n\" ";
}
if ($CRIT[1] != "") {
	$def[1] .= "LINE1:crit#ff0000:\"Critical at     \" ";
	$def[1] .= "GPRINT:crit:LAST:\"%6.2lf%S\\n\" ";
}


/*
$def[1] .= "COMMENT:\" \\n\" ";
$def[1] .= "COMMENT:\"-- debug --\\n\" ";
$def[1] .= "GPRINT:dataused:LAST:\"dataused (includes snapshot over-res.)\:  %6.2lf%S\\n\" ";
$def[1] .= "GPRINT:snapused:LAST:\"snapused (includes snapshot over-res.)\:  %6.2lf%S\\n\" ";
$def[1] .= "GPRINT:datatotal:LAST:\"datatotal\: %6.2lf%S\\n\" ";
$def[1] .= "GPRINT:snapsize:LAST:\"snapsize\:  %6.2lf%S\\n\" ";
*/

?>
