#!/usr/bin/perl


$data_file = $ARGV[0];
$total_files = $ARGV[1];

open(INFILE,$data_file) || die "Cannot open file $data_file\n";

$remote_ip = read_line();
$job_name = read_line();
$user_symbols = read_line();
$bad_symbols = read_line();
$num_reps = read_line();
$false_positive = read_line();
$percent_genes = read_line();
$core_match = read_line();
$matrix_match = read_line();
$email_addr = read_line();
$gene_input = read_line();
$txs_region = read_line();
$enhancer = read_line();
close(INFILE);

$debug = 1;

#$tfbset_dir = "/var/www/html/tf_enrichment";
$tfbset_dir = "tf_enrichment";
$tfbset_files = "tfbset-".$remote_ip."-".$job_name."-[0-9]+\.out";
$main_file = "tfbset-".$remote_ip."-".$job_name."-main.out";

@user_genes = split("\t",$user_symbols);
$num_symbols = @user_genes;	

$num_files = 0;
$j = 0;
while (($num_files < $total_files) and ($j < 45000))
{
	@filenames = ();
	opendir ( FDIR , $tfbset_dir)  || die "Can not open directory.\n";
	$i = 0;
	while (my $file = readdir(FDIR)) {
	        # We only want files
	        next unless (-f "$tfbset_dir/$file");

	        # Use a regular expression to find files beginning with "tfbset"
	        next unless ($file =~ m/^$tfbset_files/);

		# Skip the main file and the data file
		if (($file ne $main_file) and ($file ne $file_name))
		{ $filenames[$i] = $file; 
		  $i++; }
	}
	$debug++;
	$num_files = @filenames;
	sleep(2);
	$j++;
}

$debug++;

if ($num_files < $total_files)
{
$error_message = "An error has occurred. Cannot find required $total_files datafiles for job $job_name.
Your job may exceed system requirements. Please resubmit with a smaller gene set or fewer permutations.";
print "$error_message\n";
$cmd = "php tfbset_mail.php $data_file \"$error_message\" ERROR";
system($cmd);
delete_files();
exit;
}

print "Processing file $main_file\n";

%matrix_counts = {};
%matrix_genes = {};

open (INFILE, $tfbset_dir."/".$main_file) || die "Canot open file $filename\n";
$line = <INFILE>;	# Skip header line
while (<INFILE>)
{
	$line = $_;
	@rows = split("\t",$line);
	$matrix_id = $rows[0];
	$matrix_counts{$matrix_id} = $rows[1];
	$matrix_genes{$matrix_id} = trim($rows[2]);
}
close(INFILE);

$debug++;

# The following hashes will store the counts of the random gene sets.
%indiv_counts = {};
%count_totals = {};

$i = 0;
while ($i < $num_files)
{
	$filename = $tfbset_dir."/".$filenames[$i];
	print "Processing file: $filename\n";
	open (INFILE, $filename) || die "Canot open file $filename\n";
	while (<INFILE>)
	{
		$line = $_;
		@rows = split(",",$line);
		$matrix_id = $rows[0];
		$count_totals{$matrix_id} = $count_totals{$matrix_id} + $rows[1];
		$indiv_counts{$matrix_id} = $indiv_counts{$matrix_id}."\t".trim($rows[2]);

	}
	close(INFILE);

	$i++;
}

$debug++;

print "Calculating results\n";


$outfile = $tfbset_dir."/tfbs-".$remote_ip."-".$job_name."-results.out";
open (OUTFILE,">$outfile") || die "Cannot open file $outfile\n";

my @matrixes = keys %count_totals;
my $total_matrixes = @matrixes;
$j = 0;
for my $matrix (@matrixes) {

	if ($num_reps > 0)
		{ $average_count = $count_totals{$matrix}/$num_reps; }
	else
		{ $average_count = 0; }

	@data_values = split("\t",$indiv_counts{$matrix});
	$sum_squares = 0;
	$over_count = 0;
	$i = 1;
	while ($i <= $num_reps)
	{
		$sum_squares = $sum_squares + (($data_values[$i]-$average_count)*($data_values[$i]-$average_count));
		if ($data_values[$i] > $matrix_counts{$matrix})
			{ $over_count++; }
		$i++;
	}


	$standard_deviation = 0;
	if ($num_reps > 1)
		{
		$standard_deviation = sqrt($sum_squares/($num_reps-1)); 
		}

	$z_score = 0;
	if ($standard_deviation > 0)
		{
		$z_score = ($matrix_counts{$matrix} - $average_count)/$standard_deviation;
		}

	$percent_over = 100*($over_count/$num_reps);


	if (defined $matrix_genes{$matrix})
		{
		@array = split(/\+\+/,$matrix_genes{$matrix});
		$num_genes = @array;
		$percent_of_genes = 100*($num_genes/$num_symbols);
		}
	else
		{	$percent_of_genes = 0; }


	if (($percent_over <= $false_positive) and ($percent_of_genes >= $percent_genes))
	{
        print OUTFILE "$matrix,$matrix_counts{$matrix},$average_count,$standard_deviation,$z_score,$percent_over,$percent_of_genes\n";
	}

    $j++;
    } # endfor
close(OUTFILE);

$debug++;


$sort_file = $tfbset_dir."/tfbs-".$remote_ip."-".$job_name."-results.sorted";
$cmd = "sort -k6,6n -k5,5nr --field-separator=',' ".$outfile." > ".$sort_file;
#$cmd = "sort -k6,6n -k5,5nr ".$outfile." > ".$sort_file;
system($cmd);

$final_file = $tfbset_dir."/tfbs-".$remote_ip."-".$job_name."-results.csv";
$header = "Matrix Id,Count,$num_reps Replicates,Std. Dev.,Z score,False Pos. Rate (%),% Genes with Matrix,Factor Name,Rank\n";
open(FINAL, ">$final_file") || die "Cannot open file $final_file\n";
print FINAL "$header";

open (SORTED_FILE,$sort_file) || die "Cannot open file $sort_file\n";
$i = 1;
while(<SORTED_FILE>) {
	$line = trim($_);
	$line = $line.",".$i."\n";
	print FINAL "$line";
	$i++;
}
close(SORTED_FILE);
close(FINAL);

$debug++;

print "Mailing the result files\n";
$mail_message = "The following attachment contains the results of your TF Enrichment query $job_name.\n";
$cmd = "php tfbset_mail.php $data_file \"$mail_message\" success $final_file";
system($cmd);

delete_files();
exit;

#############################################################################################

sub delete_files
{
print "Deleting log files and temporary files\n";

# Delete temporary files and data file
$delete_files = "rm ".$tfbset_dir."/tfbset-".$remote_ip."-".$job_name."*"; 
system($delete_files);

$delete_files = "rm ".$outfile;	# Remove temporary result file
system($delete_files);

$delete_files = "rm ".$sort_file; # Remove temporary result file
system($delete_files);

# Delete log files
$delete_files = "rm ".$tfbset_dir."/tfbset_reps-".$remote_ip."-".$job_name."*.log";
system($delete_files);

$delete_files = "rm ".$tfbset_dir."/tfbset_main-".$remote_ip."-".$job_name.".*";
system($delete_files);

$delete_files = "rm ".$tfbset_dir."/tfbset_parse-".$remote_ip."-".$job_name.".log";
system($delete_files);
}


sub read_line
{
my $remote_id = <INFILE>;
$colon_pos = index($remote_id,":");
$remote_id = substr($remote_id,$colon_pos+1,10000);
$remote_id =~ s/\s+$//; #remove trailing spaces
$remote_id =~ s/^\s+//; # remove leading spaces
return($remote_id)
}


sub trim {
    (my $s = $_[0]) =~ s/^\s+|\s+$//g;
    return $s;        
}

