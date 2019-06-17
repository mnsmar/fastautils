#!/usr/bin/env perl

use Modern::Perl;
use IO::File;
use autodie;
use Getopt::Long::Descriptive;
use GenOO::Data::File::FASTA;
# # #  Define and read command line options
my ($opt, $usage) = describe_options(
	"Usage: %c %o",
	["converts fasta to json"],
	[],
	['fasta=s',
		'fasta file. Reads from STDIN if not provided',
	],
	['quote',
		'flag to use double quotes for values'],
	['verbose|v', 'Print progress'],
	['help|h', 'Print usage and exit',
		{shortcircuit => 1}],
);
print($usage->text), exit if $opt->help;

my $fasta_parser = GenOO::Data::File::FASTA->new(
	file => $opt->fasta
);

my %out;
while (my $record = $fasta_parser->next_record){

	my @array = split("", $record->sequence);
	if ($opt->quote){
		@array = map {'"'.$_.'"'} @array;
	}

	$out{$record->header} = '"'.$record->header.'"' . " : [".join(",", @array)."]";
}

print "{\n";
print join (",\n", (values %out));
print "\n}\n";
 
exit;

sub filehandle_for {
	my ($file) = @_;

	if ($file eq '-'){
		return IO::File->new("<-");
	}
	else {
		return IO::File->new($file, "<");
	}
}

 
