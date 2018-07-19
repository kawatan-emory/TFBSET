#!/usr/bin/perl

use DBI;

$fname = $ARGV[0];
$date_time1 = $ARGV[1];
$date_time1 = substr($date_time1,0,24);

open(INFILE,$fname) || die "Cannot open file $fname\n";

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

@months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$stat_file = "/var/www/html/tf_enrichment/tfbset_main-".$remote_ip."-".$job_name.".status";
open(STAT_FILE,">$stat_file") || die "Cannot open file $stat_file\n";
# Put leading zeros in front of minutes and seconds
$min = substr("00".$min,-2);
$sec = substr("00".$sec,-2);
$year = $year + 1900;
#print STAT_FILE "Job $job_name started at $mday-$months[$mon]-$year $hour:$min:$sec";
print STAT_FILE "Job $job_name started at $date_time1";
close(STAT_FILE);


$database = "tfbs_db";
$host = "localhost";
$dbh = DBI -> connect("DBI:mysql:$database:$host","kawatan","genomics123");


@user_genes = split("\t",$user_symbols);
@bad_genes = split("\t",$bad_symbols);

$num_symbols = @user_genes;	
$num_bad = @bad_genes;	
print "Number of valid gene symbols: $num_symbols\n";

$debug2 = 1;

print "Finding matrixes for user supplied gene symbols\n";

$i = 0;
while ($i < $num_symbols)
{
	# First find refseq id and transcription start site for the entered gene symbol
	$user_gene = trim($user_genes[$i]);
	if ($gene_input eq "refseq")
		{ $query = "select  refseq_id,chromosome,txs_start_position from RefSeq_genes_txs  where refseq_id = '$user_gene'"; }
	else
		{ $query = "select  gene_symbol,refseq_id,chromosome,txs_start_position from gene_symbols  where $gene_input = '$user_gene'"; }


	$sqlquery = $dbh->prepare($query) or die "Cannot prepare query \n";
	$rv1 = $sqlquery->execute or die "Cannot execute query $query\n";
	@row = $sqlquery->fetchrow_array; # or die "Cannot fetch $query \n";

	$chrom = $row[2];
	$txs_start = $row[3];
	$start_search = $txs_start - $txs_region;
	$end_search = $txs_start + $txs_region;

	# Next, find all the matricies associated with that gene symbol
	$query = "select matrix_id from TFBS_DB3 where (chromosome = '$chrom') and (start_position >= $start_search) and (start_position <= $end_search) and (core_match >= $core_match) and (matrix_match >= $matrix_match)  order by matrix_id";

	$sqlquery = $dbh->prepare($query) or die "Cannot prepare query \n";
	$rv1 = $sqlquery->execute or die "Cannot execute query $query\n";
	@row = $sqlquery->fetchrow_array; # or die "Cannot fetch $query \n";

	$plus_user_gene = "+".$user_gene."+";	# Put "+" symbols around the user gene to avoid gene names that are similar. Eg. "CAD" and "CAD1"
	while (defined $row[0])
	{
		$matrix_id = $row[0];
		$matrix_counts{$matrix_id} = $matrix_counts{$matrix_id} + 1;

		# Add the gene to matrix_genes if it does not already exist
		if (defined $matrix_genes{$matrix_id})
		{
			$index_value = index($matrix_genes{$matrix_id},$plus_user_gene);
			if ($index_value < 0)
			{ $matrix_genes{$matrix_id} = $matrix_genes{$matrix_id} .$plus_user_gene; }
		}
		else
			{ $matrix_genes{$matrix_id} = $plus_user_gene; }

		@row = $sqlquery->fetchrow_array; # or die "Cannot fetch $query \n";
	} # endwhile


	# Next, find all the matricies associated with that gene symbols enhancer regions
	if ($enhancer eq "X")
	{
	$query = "select matrix_id from enhancer_regions where (gene_name = '$user_gene')  and (core_match >= $core_match) and (matrix_match >= $matrix_match) order by matrix_id";

	$sqlquery = $dbh->prepare($query) or die "Cannot prepare query \n";
	$rv1 = $sqlquery->execute or die "Cannot execute query $query\n";
	@row = $sqlquery->fetchrow_array; # or die "Cannot fetch $query \n";

	while (defined $row[0])
	{
		$matrix_id = $row[0];
		$matrix_counts{$matrix_id} = $matrix_counts{$matrix_id} + 1;

		# Add the gene to matrix_genes if it does not already exist
		if (defined $matrix_genes{$matrix_id})
		{
			if (index($matrix_genes{$matrix_id},$plus_user_gene) > 0)
			{ $matrix_genes{$matrix_id} = $matrix_genes{$matrix_id} .$plus_user_gene; }
		}
		else
			{ $matrix_genes{$matrix_id} = $plus_user_gene; }

		@row = $sqlquery->fetchrow_array; # or die "Cannot fetch $query \n";
	} #endwhile
	} #endif

	$i++;
} # endwhile ($i <= $num_symbols)

$debug4 = 1;

$out_file = "/var/www/html/tf_enrichment/tfbset-".$remote_ip."-".$job_name."-main.out";
#$out_file = "/home/kwatanabe/tfbset/tfbset-".$remote_ip."-".$job_name."-main.out";

open(OUTFILE,">$out_file") || die "Cannot open file $out_file\n";

print OUTFILE "matrix\tcounts\tgenes\n";

my @matrixes = keys %matrix_counts;
for my $matrix (@matrixes) {
        print OUTFILE "$matrix\t$matrix_counts{$matrix}\t$matrix_genes{$matrix}\n";
}

close(OUTFILE);
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






