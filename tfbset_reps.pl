#!/usr/bin/perl

use DBI;

$fname = $ARGV[0];
$job_num = $ARGV[1];
$num_reps = $ARGV[2];
open(INFILE,$fname) || die "Cannot open file $fname\n";

$remote_ip = read_line();
$job_name = read_line();
$user_symbols = read_line();
$bad_symbols = read_line();
$temp_var = read_line();
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

$database = "tfbs_db";
$host = "localhost";
$dbh = DBI -> connect("DBI:mysql:$database:$host","kawatan","genomics123");

@temp_genes = split("\t",$user_symbols);
$num_symbols = @temp_genes;

$debug2 = 1;

print "Loading all the gene symbols into an array\n";
if ($gene_input eq "refseq")
	{ $sql_cmd = "select refseq_id from RefSeq_genes_txs"; }
else
	{ $sql_cmd = "select $gene_input,refseq_id from gene_symbols where $gene_input is not null"; }

my $sqlquery = $dbh->prepare($sql_cmd) or die "Cannot prepare query \n";
my $rv1 = $sqlquery->execute or die "Cannot execute query $sql_cmd\n";
my @row = $sqlquery->fetchrow_array or die "Cannot fetch $sql_cmd\n";
my $i = 0;
while (defined $row[0])
{
	$i++;
	$gene_symbols[$i] = $row[0];
	@row = $sqlquery->fetchrow_array; # or die "Cannot fetch $sql_cmd\n";
}
print "Loaded $i gene symbols\n";
$TOTAL_GENES= $i;


$debug3 = 1;



print "Performing queries for $num_symbols random gene symbols for $num_reps permutations\n";

# Initialize hashes
my %indiv_counts;
my %count_totals;

$j = 1;
while ($j <= $num_reps)
{

print "Replicate: $j\n";

# Randomly pick  $num_symbols of genes and count the number of entries in the TFs_profile_count table and 
# store the results into the %results hash.
my %results;	# initialize hash
$i = 1;
while ($i <= $num_symbols)
{
	$gene_num = int(rand($TOTAL_GENES));

	# First find refseq id and transcription start site for the random gene symbol
	if ($gene_input eq "refseq")
		{ $query = "select  refseq_id,chromosome,txs_start_position from RefSeq_genes_txs  where refseq_id = '$gene_symbols[$gene_num]'"; }
	else
		{ $query = "select  gene_symbol,refseq_id,chromosome,txs_start_position from gene_symbols  where $gene_input = '$gene_symbols[$gene_num]'"; }

	$sqlquery = $dbh->prepare($query) or die "Cannot prepare query \n";
	$rv1 = $sqlquery->execute or die "Cannot execute query $query\n";
	@row = $sqlquery->fetchrow_array; # or die "Cannot fetch $query \n";

	$chrom = $row[2];
	$txs_start = $row[3];
	$start_search = $txs_start - $txs_region;
	$end_search = $txs_start + $txs_region;

if (defined $row[0])
{
	# Next, find all the matricies associated with that gene symbol
	$query = "select matrix_id from TFBS_DB3  where (chromosome = '$chrom') and (start_position >= $start_search) and (start_position <= $end_search) and (core_match >= $core_match) and (matrix_match >= $matrix_match)  order by matrix_id";
	$sqlquery = $dbh->prepare($query) or die "Cannot prepare query \n";
	$rv1 = $sqlquery->execute or die "Cannot execute query $query\n";
	@row = $sqlquery->fetchrow_array; # or die "Cannot fetch $query \n";

	while (defined $row[0])
	{
		$matrix_id = $row[0];
		$results{$matrix_id} = $results{$matrix_id} + 1;
		@row = $sqlquery->fetchrow_array; # or die "Cannot fetch $query \n";
	}
}

	$debug4 = 1;
	# Next, find all the matricies associated with that gene symbols enhancer regions
	if ($enhancer eq "X")
	{
	$user_gene = $gene_symbols[$gene_num];
	$query = "select matrix_id from enhancer_regions where (gene_name = '$user_gene')  and (core_match >= $core_match) and (matrix_match >= $matrix_match) order by matrix_id";
	$sqlquery = $dbh->prepare($query) or die "Cannot prepare query \n";
	$rv1 = $sqlquery->execute or die "Cannot execute query $query\n";
	@row = $sqlquery->fetchrow_array; # or die "Cannot fetch $query \n";

	while (defined $row[0])
	{
		$matrix_id = $row["matrix_id"];
		$results{$matrix_id} = $results{$matrix_id} + 1;
		@row = $sqlquery->fetchrow_array; # or die "Cannot fetch $query \n";
	}
	} #endif

	$i++;

} #endwhile $i <= num_symbols

$debug4 = 1;

	@matrixes = keys %results;
	foreach $matrix (@matrixes) {
		$count_totals{$matrix} = $count_totals{$matrix} + $results{$matrix};
		$indiv_counts{$matrix} = $indiv_counts{$matrix}."\t".$results{$matrix};
	}

	$j++;
} #endwhile ($j <= $num_reps)

$debug5 = 1;

print "printing out the final results\n";
$fname = "/var/www/html/tf_enrichment/tfbset-".$remote_ip."-".$job_name."-".$job_num.".tmp";
$fname2 = "/var/www/html/tf_enrichment/tfbset-".$remote_ip."-".$job_name."-".$job_num.".out";

open(OUTFILE,">$fname") or die "Unable to open file $fname";

@matrixes = keys %count_totals;
foreach $matrix (@matrixes) {

	$result_string =  $matrix.",".$count_totals{$matrix}.",".$indiv_counts{$matrix}."\n";
	print OUTFILE "$result_string";
	}


close(OUTFILE);

$cmd = "mv $fname $fname2";
system($cmd);

exit;






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






