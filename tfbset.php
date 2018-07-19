<?php

require_once('/var/www/html/connTFBS.php'); 	# Connect to the database

$user_symbols = test_input($_POST["gene_symbols"]);
$gene_input=$_POST["gene_input"];
$user_symbols = str_replace("'", "",$user_symbols); # remove single quotes as they mess things up
$user_genes = explode("\n",$user_symbols);
$num_genes = count($user_genes);
$gene_list = "";
$bad_genes = "";
$i = 0;
while ($i < $num_genes)
{
	$temp_gene = trim($user_genes[$i]);
	$first_char = substr($temp_gene,0,1);
	if  (($first_char != "#") and ($first_char != "!"))
		{ 
		if ($gene_input == "refseq")
			{ $query = "select  refseq_id from RefSeq_genes_txs  where refseq_id = '$temp_gene'"; }
		else
			{ $query = "select  $gene_input from gene_symbols  where $gene_input = '$temp_gene'"; }


		$sql = mysqli_query($connGS,$query) or die(mysql_error());
		if ($row = mysqli_fetch_assoc($sql))
			{
			$gene_list = $gene_list."\t".$temp_gene; 
			}
		else
			{
			$bad_genes = $bad_genes."\t".$temp_gene;
			}
		}
	$i++;
}

$num_reps = $_POST["Replicates"];
$false_positive = $_POST["false_positive"];
$percent_genes = $_POST["percent_of_genes"];
$core_match=$_POST["core_score"];
$matrix_match=$_POST["matrix_score"];
$email_addr=$_POST["email_addr"];
$job_name=test_input($_POST["job_name"]);
$txs_region = $_POST["txs_region"];
$enhancer = $_POST["enhancer"];
$date_time = $_POST["date_time"];

$ip = $_SERVER['REMOTE_ADDR'];

$data_file = "/var/www/html/tf_enrichment/tfbset-".$ip."-".$job_name.".data";

function test_input($data) {
  $data = trim($data);
  $data = stripslashes($data);
  $data = htmlspecialchars($data);
  return $data;
}

?>


<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Transcription Factor Enrichment Tool</title>

<script src="menu_style.js"></script>

<style>
.box
{
   width : 60px;
   font-family : arial;
   font-size : 12px;
}
</style>

</head>

<body>

<table cellpadding="0" margin="0" cellspacing="0" width="99%">
<tr>
<td text="#000000"  height="21" bgcolor="3333CC">
</td>
</tr> 
<tr>
<td text="#000000"  height="10" bgcolor="3333CC"> 
</td>
</tr> 
<tr>
<td align = "left" height = 63>
<img SRC="Emory-logo.jpg"  vspace="1"></left>
<img SRC="emorybannertext.jpg"  vspace="1" hspace="100">
<center><img SRC="experimentlpath.gif"  vspace="1" height=50 width=250></center>
</td>
</tr>  
<tr>
<td text="#000000"  height="9" bgcolor="3333CC"> 
</td>
</tr> 
<tr>
<td text="#000000"  height="20" bgcolor="3333CC" align = "center">
<font face = "arial" color = "#FFFFFF" size = "4">
<b>
Transcription Factor Binding Site Enrichment Tool
</b>
</font>
</td>
</tr> 
</table>

<script src="menu.js"></script>

<h2 style="text-align:center">
<?php


if (file_exists($data_file))
{
	echo "WARNING: You currently have a job in progress with the job name $job_name.<br>
	If you wish to submit another job, please use a different job name. <br>Thank you.<br>";
	$myfile = fopen($data_file, "r") or die("Unable to open file!");
#	echo fread($myfile,filesize($data_file));
	fclose($myfile);
}
else
{

$outfile = fopen($data_file, "w") or die("Unable to open file $data_file!");
fwrite($outfile, $ip."\n");
fwrite($outfile, $job_name."\n");
fwrite($outfile, $gene_list."\n");
fwrite($outfile, $bad_genes."\n");
fwrite($outfile, $num_reps."\n");
fwrite($outfile, $false_positive."\n");
fwrite($outfile, $percent_genes."\n");
fwrite($outfile, $core_match."\n");
fwrite($outfile, $matrix_match."\n");
fwrite($outfile, $email_addr."\n");
fwrite($outfile, $gene_input."\n");
fwrite($outfile, $txs_region."\n");
fwrite($outfile, $enhancer."\n");
fclose($outfile);

$cmd = "perl /var/www/html/tfbset_main.pl $data_file '$date_time' > /var/www/html/tf_enrichment/tfbset_main-".$ip."-".$job_name.".log &";
#$cmd = "perl /var/www/html/tfbset_main.pl $data_file > /var/www/html/tf_enrichment/tfbset_main-".$ip."-".$job_name.".log &";
exec($cmd);
# echo "exec: $cmd<br>";

$num_jobs = 16;
if ($num_reps%$num_jobs == 0)
	{ $sub_reps = $num_reps/$num_jobs; }
else
	{ $sub_reps = intval($num_reps/$num_jobs) + 1; }

$i = 1;
$remaining_reps = $num_reps;
while (($i <= $num_jobs) and ($remaining_reps > 0))
{
	if ($remaining_reps < $sub_reps)
		{
		$sub_reps = $remaining_reps; 
		$num_jobs = $i;	#Sometimes fewer jobs are submitted, ie $i never gets to $num_jobs
		}
	$remaining_reps = $remaining_reps - $sub_reps;

	$cmd = "perl /var/www/html/tfbset_reps.pl $data_file $i $sub_reps > /var/www/html/tf_enrichment/tfbset_reps-".$ip."-".$job_name."-".$i.".log &";
	exec($cmd);
#	echo "exec: $cmd<br>";
	$i++;
}

$cmd = "perl /var/www/html/tfbset_parse.pl $data_file $num_jobs > /var/www/html/tf_enrichment/tfbset_parse-".$ip."-".$job_name.".log &";
exec($cmd);


echo "Your job has been submitted and the results will be sent to the email provided. <br>";
echo "Please wait until you receive an email of your results before submitting another job.<br>";
echo "Thank you.<br>";
}

?>
</h2>

<center>
<FORM><INPUT Type="button" VALUE="Back" style="font-size:20px" onClick="history.go(-1);return true;"></FORM>
</center>

</body>

</html>
