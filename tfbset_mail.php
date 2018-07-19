<?php

require_once('/var/www/html/class.phpmailer.php'); 
require_once('/var/www/html/class.smtp.php');

$param_array = $_SERVER['argv'];
$php_file = $param_array[0];
$data_file = $param_array[1];
$mail_message = $param_array[2];
$error_stat = $param_array[3];
$mail_file = $param_array[4];

$data_handle = fopen($data_file, "r") or die("Unable to open file $data_gile!\n");
$remote_ip = trim(fgets($data_handle));
$job_name = trim(fgets($data_handle));
$user_symbols = trim(fgets($data_handle));
$bad_symbols = trim(fgets($data_handle));
$num_reps = trim(fgets($data_handle));
$false_positive = trim(fgets($data_handle));
$percent_genes = trim(fgets($data_handle));
$core_match = trim(fgets($data_handle));
$matrix_match = trim(fgets($data_handle));
$email_addr = trim(fgets($data_handle));
$gene_input = trim(fgets($data_handle));
$txs_region = trim(fgets($data_handle));
$enhancer = trim(fgets($data_handle));
$prostate = trim(fgets($data_handle));
fclose($data_handle);

if ($enhancer == "")
{
	$enhancer = "No";
}

$user_genes = explode("\t",$user_symbols);
$num_symbols = count($user_genes);
$bad_genes = explode("\t",$bad_symbols);
$num_bad = count($bad_genes);


echo "Sending email to $email_addr\n";

$body = "$mail_message
Number of gene symbols: $num_symbols
Number of permutations: $num_reps
False positive rate(%): $false_positive
Minimum percent of genes: $percent_genes
Minimum matrix core score: $core_match
Minimum total matrix score: $matrix_match
Enhancer regions included: $enhancer
Region around TSS: $txs_region\n";

$b = 0;
while ($b < $num_bad)
{
	$body = $body."Gene symbol not found: ".$bad_genes[$b]."\n";
	$b++;
}


$email = new PHPMailer();
#$email->From      = 'noreply@emory.edu';
#$email->FromName  = 'TF Enrichment';
$email->setFrom("noreply@emory.edu", "Emory.com");

if ($error_stat == "ERROR")
{
$email->Subject   = "ERROR in TF Enrichment ( $job_name)";
$email->Body      = $body;
$email->AddAddress( $email_addr );
}
else
{
$email->Subject   = "TF Enrichment ( $job_name)";
$email->Body      = $body;
$email->AddAddress( $email_addr );
$email->AddAttachment( $mail_file );
}

if(!$email->Send())
{
   echo "Message could not be sent. \n";
   echo "Mailer Error: " . $mail->ErrorInfo;
   echo "\n";
}
else
{
echo "Message has been sent\n";
}


echo "Finished\n";

?>
