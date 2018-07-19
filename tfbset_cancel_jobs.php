<?php

$param1 = $_POST["param1"];

$ip = $_SERVER['REMOTE_ADDR'];

#echo "param1: $param1\n";

if (empty($_POST["param1"]))
	{ echo "No jobs selected for cancellation"; return; }
else
	{ 
	$jobs = explode("\n",$param1);
	$num_count = count($jobs);
	$index = 0;
	$job_count = 0;
	while ($index < $num_count)
		{

		$colon_pos = strpos($jobs[$index],"|");
		if ($colon_pos > 0)
			{
			$job_id = substr($jobs[$index],0,$colon_pos);
			$job_ids[$job_count] = "/var/www/html/tf_enrichment/tfbset-$ip-".substr($jobs[$index],0,$colon_pos).".data";
			$job_file = substr($jobs[$index],$colon_pos+1,100);
			// delete log files main, parse and reps
			unlink($job_file);	// delete main status file
			array_map('unlink', glob("/var/www/html/tf_enrichment/tfbset_main-$ip-$job_id.log")); //delete main log file
			array_map('unlink', glob("/var/www/html/tf_enrichment/tfbset-$ip-$job_id-main.out")); //delete main output file
			array_map('unlink', glob("/var/www/html/tf_enrichment/tfbset-$ip-$job_id-main.out")); //delete main output file
			array_map('unlink', glob("/var/www/html/tf_enrichment/tfbset_reps-$ip-$job_id*.log")); //delete reps log files
			array_map('unlink', glob("/var/www/html/tf_enrichment/tfbset-$ip-$job_id*-reps.out")); //delete reps output files
			array_map('unlink', glob("/var/www/html/tf_enrichment/tfbset_parse-$ip-$job_id*.log")); //delete parse log files
			array_map('unlink', glob("/var/www/html/tf_enrichment/tfbset-$ip-$job_id.data")); //delete data file
#			echo "job num: $job_count job: $job_ids[$job_count] file: $job_file \n";
			$job_count++;
			}
		$index++;
		}
	}
if ($job_count == 0)
{ 
echo "No jobs selected for cancellation.";
return; 
}
$num_jobs = $job_count;

$temp_file =  "/var/www/html/tf_enrichment/kill$ip.out";
$cmd = "ps -ef | grep $ip > $temp_file";
exec($cmd);


$myfile = fopen($temp_file, "r") or die("Unable to open file!");
$ps_data =  fread($myfile,filesize($temp_file));

$temp_array = preg_split(" /\n/",$ps_data);
$num_procs = count($temp_array);
unlink($temp_file);
echo "num processes: $num_procs\n";
echo "ip address: $ip\n";
echo "num_jobs: $num_jobs\n";

$found = 0;
$i = 0;
while ($i < $num_procs)
{
	$data_array = preg_split(" /\s+/",$temp_array[$i]);
	$proc_id = $data_array[1];
	$data_file = $data_array[9];

#	echo "$i proc_id: $data_array[1]\n";
#	echo "$i data_file: $data_file ".strlen($data_file)."\n";
#	echo "$i job_id[0]: $job_ids[0] ".strlen($job_ids[0])."\n";

	$found = 1;
	$index = 0;
	while ($index < $num_jobs)
	{
		if ($data_file == $job_ids[$index])
		{
#			echo "found $data_file\n";
#			echo "killing process $proc_id\n";
			$cmd = "kill $proc_id";
			exec($cmd);
			$index = $num_jobs;
		}
		$index++;
	}

	$i++;
}
echo "Jobs successfully cancelled.\n";
?>

