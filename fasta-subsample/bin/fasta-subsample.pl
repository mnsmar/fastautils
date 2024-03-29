#!/home/mns/.plenv/shims/perl

=head1 NAME

fasta-subsample - Takes a (normally random) subset of sequences in a FASTA file.

=head1 SYNOPSIS

fasta-subsample <fasta> <n> [-seed <seed>] [-norand] [-rest <rest>]
    [-off <off>] [-len <len>]

    <fasta>         name of FASTA sequence file
    <n>             number of sequences to output
    [-seed <seed>]  random number seed; default: 1
    [-norand]       disable random selection and selects sequences in file order;
                     overrides the -seed option
    [-rest <rest>]  name of file to receive the FASTA
                     sequences not being output; default: none
    [-off <off>]    print starting at position <off> in each
                     sequence; default: 1
    [-len <len>]    print up to <len> characters for each 
                     sequence; default: print entire sequence

    Output a subsample of size <n> of the sequences in a FASTA sequence
    file.  By default the sequences will be selected using a random number
    generator that is always seeded to 1 resulting in the same subset of
    sequences always being output.  You may modify the seed of the random
    number generator and hence the selected subset by using the -seed option
    or alternatively you may disable it altogether with the -norand option
    and just select the first <n> sequences in the file.  If requested, the
    remaining sequences will be output to a file named <rest>, which is useful
    for cross-validation.

    You can also choose to only output portions of each sequence
    using the -off and -len switches.  If the sequences have 
    UCSC BED file headers (e.g., ">chr1:0-99999"), the headers will
    be adjusted to reflect -off and -len.

    Writes to standard output.
=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

# constants
my $line_size = 50;  # size of lines to print

################################################################################
# print (a portion of) a FASTA sequence
# Assumes FASTA file is open and the index contains
# the file byte offset for a given ID.
################################################################################
sub print_fasta_seq_portion {
  my ($fasta, $output, $id, $off, $len, $index) = @_;

  my $addr = $index->{$id};		# address of sequence 
  die "Can't find target $id.\n" unless (defined($addr));
  seek($fasta, $addr, 0);		# move to start of target

  # save ID line
  my $id_line = <$fasta>;

  my $seq = "";
  # read in sequence lines for this sequence
  while (<$fasta>) {			# read sequence lines
    if (/^>/) {last}			# start of next sequence
    chop;
    $seq .= $_;
  }

  # get length of sequence
  my $length = length($seq);

  # print ID of FASTA sequence
  $_ = $id_line;
  if (/^(>chr[\dXY]+):(\d+)-(\d+)/i) {	# handle BED format
    my $chr = $1;
    my $start = $2;
    my $end = $3;
    my $comment = $'; 
    $start = $start + ($off - 1);	# new start; 0-based
    # BED end is really "end+1"
    $end = ($len != -1) ? $start + $len : $start + $length;
    # print ID for the sequence in BED format, adjusting for offset and length
    printf($output "%s:%s-%s%s", $chr, $start, $end, $comment);
  } else {				# handle other formats
    printf($output $_);			# print ID for this sequence
  }

  # print sequence in lines of length $line_size
  # get portion of sequence to print if -off and/or -len given
  if ($off != 1 || $len != -1) {
    if ($len == -1) {
      $seq = substr($seq, $off-1);
    } else {
      $seq = substr($seq, $off-1, $len);
    }
  }
  for (my $i = 0; $i < length($seq); $i += $line_size) {
    print $output substr($seq, $i, $line_size), "\n";
  }
}

################################################################################
# shuffle a list in place
################################################################################
sub shuffle { 
    my $r=pop; 
    $a = $_ + rand @{$r} - $_ 
      and @$r[$_, $a] = @$r[$a, $_] 
        for (0..$#{$r}); 
}

################################################################################
# Main program
################################################################################
# set defaults
my $seed = 1; # random number seed
my $norand = 0; # when enabled do not shuffle! Instead pick the first sequences as the subsample
my $off = 1; # first position of sequence to print
my $len = -1; # maximum length of sequence to print
my $rest = ""; # file to receive remainder of seqs
my $help = 0; # when enabled show help
 
# read settings
GetOptions(
  'seed=i'  => \$seed,
  'norand'  => \$norand,
  'rest=s'  => \$rest,
  'off=i'   => \$off,
  'len=i'   => \$len,
  'help|?'  => \$help
) or pod2usage(2);
pod2usage(1) if $help;
pod2usage("Missing required arguments.") if (scalar(@ARGV) < 2);
my ($fasta, $n) = @ARGV;
pod2usage("Required FASTA file \"$fasta\" does not exist.") unless (-e $fasta);
pod2usage("Required sequence count \"$n\" is not a whole number.") unless ($n =~ m/^\d+$/);

# read in FASTA file and make index
open(FASTA, "<$fasta") || die "Couldn't open file `$fasta'.\n";
my $byte = 0;
my %index;			# ID-to-start index
my $id;				# sequence ID
my @rest;			# dummy
my @id_list;			# list of all IDs
while (<FASTA>) {
  if (/^>/) {
    ($id, @rest) = split;
    $index{$id} = $byte; # start of sequence record
    push @id_list, $id;
  } 
  $byte += length;
} # read FASTA file

# check that there are enough IDs, if not adjust $n
my $nseqs = @id_list;
if ($nseqs < $n) {
	warn ("warning: not enough sequences ($nseqs); $n requested.\n");
	$n = $nseqs;
}

unless ($norand) {
  # shuffle the list of IDs
  srand($seed);
  shuffle(\@id_list);
  #print join " ", @id_list, "\n";
}

# output the requested number of FASTA sequences to STDOUT
foreach $id (@id_list[0..$n-1]) { 
  print_fasta_seq_portion(*FASTA, *STDOUT, $id, $off, $len, \%index);
} # id

# output the remainder of the sequences if requested
# to the "rest" file
if ($rest) {
  open(REST, ">$rest") || die("Can't open file `$rest'.\n");
  foreach $id (@id_list[$n..$nseqs-1]) { 
    print_fasta_seq_portion(*FASTA, *REST, $id, $off, $len, \%index);
  }
}

1;
