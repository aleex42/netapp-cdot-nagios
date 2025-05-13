<?php
#
# check_cdot_volume.php - based on check_netappfileri_vol.php from 
# https://github.com/wAmpIre/check_netappfiler
#

$num = 1;
foreach ($DS as $i=>$VAL) {
	if (preg_match('/^(.*?)__space_used/', $NAME[$i])) {
		$ds_name[$num] = preg_replace("/Vol_(.*)::check_cdot_volume_usage.*/", "$1", $LABEL[$i]);
		$opt[$num] = "--title=\"Volume $hostname / $ds_name[$num]\" --vertical-label=\"Bytes\" --lower-limit=0 --base=1024 --rigid ";

		$def[$num] = rrd::def("dataused", $RRDFILE[$i], $DS[$i], "AVERAGE");
		$def[$num] .= rrd::def("inodeused",$RRDFILE[$i+1], $DS[$i+1], "AVERAGE");
		$def[$num] .= rrd::def("snapused", $RRDFILE[$i+2], $DS[$i+2], "AVERAGE");
		$def[$num] .= rrd::def("datatotal",$RRDFILE[$i+3], $DS[$i+3], "AVERAGE");
		$def[$num] .= rrd::def("snapsize", $RRDFILE[$i+4], $DS[$i+4], "AVERAGE");

		$def[$num] .= "CDEF:snapover=snapused,snapsize,GT,snapused,snapsize,-,0,IF ";
		$def[$num] .= "CDEF:snapfree=snapused,snapsize,GT,0,snapsize,snapused,-,IF ";
		$def[$num] .= "CDEF:snapwoover=snapused,snapover,- ";
		$def[$num] .= "CDEF:snapsizepct=snapsize,datatotal,/,100,* ";

		$def[$num] .= "CDEF:datausedpct=dataused,datatotal,/,100,* ";
		$def[$num] .= "CDEF:datausedwoover=dataused,snapover,- ";
		$def[$num] .= "CDEF:datafree=datatotal,datausedwoover,-,snapover,- ";

		if ($WARN[$i] != "") $def[$num] .= "CDEF:warn=dataused,0,*,$WARN[$i],+ ";
		if ($CRIT[$i] != "") $def[$num] .= "CDEF:crit=dataused,0,*,$CRIT[$i],+ ";

		$def[$num] .= "AREA:datausedwoover#aaaaaa:\"Data\: Used space\" ";
		$def[$num] .= "GPRINT:datausedwoover:LAST:\"%6.2lf%S\\n\" ";
		$def[$num] .= "AREA:datafree#00ff00:\"Data\: Free space\":STACK ";
		$def[$num] .= "GPRINT:datafree:LAST:\"%6.2lf%S\\n\" ";
		$def[$num] .= "AREA:snapover#aa0000:\"Snap\: Over resv.\":STACK ";
		$def[$num] .= "GPRINT:snapover:LAST:\"%6.2lf%S\\n\" ";
		$def[$num] .= "AREA:snapfree#00ffff:\"Snap\: Free space\":STACK ";
		$def[$num] .= "GPRINT:snapfree:LAST:\"%6.2lf%S\\n\" ";
		$def[$num] .= "AREA:snapwoover#0000cc:\"Snap\: Used space\":STACK ";
		$def[$num] .= "GPRINT:snapwoover:LAST:\"%6.2lf%S\\n\" ";

		$def[$num] .= "LINE1:datatotal#000000 ";

		$def[$num] .= "LINE2:datafree#ffffff:\"Available space \" ";
		$def[$num] .= "GPRINT:datafree:LAST:\"%6.2lf%S\\n\" ";

		$def[$num] .= "COMMENT:\" \\n\" ";
		$def[$num] .= "GPRINT:datatotal:LAST:\"Configured visible data space\: %6.2lf%S\\n\" ";
		$def[$num] .= "GPRINT:snapsize:LAST:\"Configured snapshot resv.\:     %6.2lf%S\" ";
		$def[$num] .= "GPRINT:snapsizepct:LAST:\"(%6.2lf%% of the volume)\\n\" ";

		$def[$num] .= "COMMENT:\" \\n\" ";
		$def[$num] .= "GPRINT:dataused:LAST:\"Data used space incl. snapshot over resv.\: %6.2lf%S\" ";
		$def[$num] .= "GPRINT:datausedpct:LAST:\"(%6.2lf%%)\\n\" ";
		if ($WARN[$i] != "") {
			$def[$num] .= "LINE1:warn#ffff00:\"Warning at      \" ";
			$def[$num] .= "GPRINT:warn:LAST:\"%6.2lf%S\\n\" ";
		}
		if ($CRIT[$i] != "") {
			$def[$num] .= "LINE1:crit#ff0000:\"Critical at     \" ";
			$def[$num] .= "GPRINT:crit:LAST:\"%6.2lf%S\\n\" ";
		}

/*
		$def[$num] .= "COMMENT:\" \\n\" ";
		$def[$num] .= "COMMENT:\"-- debug --\\n\" ";
		$def[$num] .= "GPRINT:dataused:LAST:\"dataused (includes snapshot over-res.)\:  %6.2lf%S\\n\" ";
		$def[$num] .= "GPRINT:snapused:LAST:\"snapused (includes snapshot over-res.)\:  %6.2lf%S\\n\" ";
		$def[$num] .= "GPRINT:datatotal:LAST:\"datatotal\: %6.2lf%S\\n\" ";
		$def[$num] .= "GPRINT:snapsize:LAST:\"snapsize\:  %6.2lf%S\\n\" ";
*/

		$num++;
	}
}

array_multisort($ds_name, SORT_NATURAL, $opt, $def);
