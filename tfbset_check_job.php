<?php

$ip = $_SERVER['REMOTE_ADDR'];
$status_file = "/var/www/html/tf_enrichment/tfbset_main-$ip-*.status";

$msgtxt = "";

$filelist = glob($status_file);

#echo "$filelist[0]:$filelist[0]:$filelist[0]\n$filelist[1]:$filelist[1]:$filelist[1]\n";

$i = 0;
if (isset($filelist[$i]))
{
	while (isset($filelist[$i]))
	{
	$msgtxt = $msgtxt.$filelist[$i]."|"; 

	$ip_pos = strpos($filelist[$i],$ip);
	$job_id = substr($filelist[$i],$ip_pos+strlen($ip),1000);
	$dot_pos = strpos($job_id,".");
	$job_id = substr($job_id,1,$dot_pos-1);

	$msgtxt = $msgtxt."$job_id|";

	$myfile = fopen($filelist[$i], "r") or die("Unable to open file!");
	$msgtxt = $msgtxt. fread($myfile,filesize($filelist[$i]));

	$msgtxt = $msgtxt."\n";

	$i++;
	}
	$msgtxt = trim($msgtxt);
	echo "$msgtxt";
}

?>
