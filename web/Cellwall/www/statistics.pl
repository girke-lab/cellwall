#!/usr/bin/perl -w
# This script is the CGI interface to the Index module

use lib  qw( /srv/web/Cellwall/lib );


use strict;
use Cellwall;
use Cellwall::CGI;
use Cellwall::Web::Index;
use Error;

# Create the CGI object
my $cgi = new Cellwall::Web::Index(
	-author  => [ -link => ['Josh Lauricha', 'mailto:laurichj@bioinfo.ucr.edu']],
	-created => "31 Mar 2004",
	-updated => "31 Mar 2004",
);

# Parse the user input.
$cgi->parse();

# Get the Cellwall object
my $cw = $Cellwall::singleton;

my $stats;
my $sth;
my $results;

my $sql =  $Cellwall::singleton->sql();

# Get the number of groups
$sth = $sql->prepare('SELECT count(*) FROM groups');
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{__total}->{'Number of Groups'} = $results->[0]->[0] || die 'unable to get number of groups';

# Get the number of families
$sth = $sql->prepare('SELECT count(*) FROM family');
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{__total}->{'Number of Families'} = $results->[0]->[0] || die 'unable to get number of families';

# Get the number of sequences
$sth = $sql->prepare('SELECT count(*) FROM sequence');
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{__total}->{'Number of Sequences'} = $results->[0]->[0] || die 'unable to get number of sequences';

# Get the number of blasts performed
$sth = $sql->prepare("SELECT COUNT(DISTINCT query) FROM blast_hsp");
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{__total}->{'Number of BLASTs Finished, with results'} = $results->[0]->[0] || die 'unable to get number of BLASTs';

# Get the number of ESTs
$sth = $sql->prepare("SELECT count(*) FROM blast_hit");
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{__total}->{'Number of ESTs'} = $results->[0]->[0] || die 'unable to get number of ESTs';

# Get the number of sequences per family
$sth = $sql->prepare('SELECT family.name, count(*) FROM sequence JOIN family on family.id = sequence.family GROUP BY family.id');
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{$_->[0]}->{'Number of Sequences'} = $_->[1] foreach @$results;

# Get the number of sequences broken down by source
$sth = $sql->prepare('SELECT genome.name, count(*) FROM sequence JOIN db ON db.id = sequence.db JOIN genome ON genome.id = db.genome GROUP BY sequence.db');
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{__total}->{sprintf('Sequences in %s', $_->[0])} = $_->[1] foreach @$results;

# Get the number of sequences per family broken down by source
$sth = $sql->prepare('SELECT family.name, genome.name, count(*) FROM sequence JOIN family ON family.id = sequence.family JOIN db ON db.id = sequence.db JOIN genome ON genome.id = db.genome GROUP BY family.id, sequence.db');
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{$_->[0]}->{sprintf('Sequences in %s', $_->[1])} = $_->[2] foreach @$results;

# Get the number of sequences per family broken down by source
$sth = $sql->prepare('SELECT genome.name, count(*) FROM sequence JOIN db ON db.id = sequence.db JOIN genome ON genome.id = db.genome GROUP BY sequence.db');
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{__total}->{sprintf('Number of Sequences in %s', $_->[0])} = $_->[1] foreach @$results;


# Get the number or HSPs
$sth = $sql->prepare('SELECT count(*) FROM blast_hsp');
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{__total}->{'Blast HSPs'} = $results->[0]->[0] || die 'unable to get number of blast hsps';

# Get the number of blast hsps per family
$sth = $sql->prepare('SELECT family.name, count(*) FROM blast_hsp JOIN sequence ON sequence.id = blast_hsp.query JOIN family ON family.id = sequence.family GROUP BY family.id');
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{$_->[0]}->{'Blast HSPs'} = $_->[1] foreach @$results;

# Get the number of blast hsps per source
$sth = $sql->prepare('SELECT genome.name, count(blast_hsp.id) FROM blast_hsp JOIN sequence ON sequence.id = blast_hsp.query JOIN db ON db.id = sequence.db JOIN genome ON genome.id = db.genome GROUP BY genome.id');
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{__total}->{sprintf('Blast HSPs from sequences in %s', $_->[0])} = $_->[1] foreach @$results;

# Get the number of blast hsps per family per source
$sth = $sql->prepare('SELECT family.name, genome.name, count(blast_hsp.id) FROM blast_hsp JOIN sequence ON sequence.id = blast_hsp.query JOIN db ON db.id = sequence.db JOIN genome ON genome.id = db.genome JOIN family ON family.id = sequence.family GROUP BY family.id, genome.id');
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{$_->[0]}->{sprintf('Blast HSPs from sequences in %s', $_->[1])} = $_->[2] foreach @$results;

# Get the number of blast hsps per query per family
$sth = $sql->prepare('SELECT family.name, COUNT(hsp.id) / COUNT(DISTINCT sequence.id) FROM family JOIN sequence ON family.id = sequence.family JOIN blast_hsp AS hsp ON sequence.id = hsp.query GROUP BY family.id');
$sth->execute();
$results = $sth->fetchall_arrayref();
$stats->{$_->[0]}->{'HSPs per Sequence'} = $_->[1] foreach @$results;

# Make the table
foreach my $family (sort { ( $a eq '__total' ) ? -1 : ($b eq '__total') ? 1 : $a cmp $b } keys %$stats ) {
	$cgi->add_Table(
		-format => [
			[ -width => '40%' ],
			[ -width => '60%' ],
		],
		-header => [ [  -colspan => 2, $family eq '__total' ? 'Totals' : $family ] ],
		map {
			-row => [ $_, commify($stats->{$family}->{$_}) ],
		} sort keys(%{$stats->{$family}})
	);
}

$cgi->display();

sub commify 
{
	my $text = reverse($_[0]);
	$text =~ s/(\d\d\d)(?=\d)(?!\d+\.)/$1,/g;
	return scalar(reverse($text));
}

