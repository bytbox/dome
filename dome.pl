#!/usr/bin/perl

use strict;
use warnings;

use Fcntl ':flock';

use constant VERSION => 0.1;

sub usage {
	print STDERR <<END;
usage: $0 done [:id] "Task description"
       $0 todo [:id] "Task description"
       $0 drop [:]id
       $0 list [all]
       $0 search [keyword] ...
       $0 version
END
	exit -1;
}

sub random_id {
	int rand(1<<30);
}

# Parse task data from the command line
sub task_data {
	my ($complete, $id, $desc) = (shift, "", shift);
	print STDERR "$0: parse: missing task description\n" and exit -1 unless $desc;
	if ($desc =~ /^:(.+)/) {
		# It's an id, not a description.
		$id = $1;
		$desc = shift || "";
	} else {
		$id = random_id;
	}
	(
		id => $id,
		desc => $desc,
		complete => $complete
	)
}

usage if $#ARGV == -1;

# Get lock
my $lfname = "$ENV{HOME}/.dome.lock";
open LOCK, ">>$lfname" or die $!;
flock LOCK, LOCK_EX or die $!;

# Load task database
my %db;
my $dbfname = "$ENV{HOME}/.dome";
if (-f $dbfname) {
	open DB, $dbfname or die $!;
	while (<DB>) {
		chomp;
		my @line = split /\t/;
		my %td = task_data @line;
		$db{$td{id}} = \%td;
	}
	close DB or die $!;
}

my %commands = (
	version => sub {
		printf "dome version %s\n", VERSION;
		exit 0;
	},

	done => sub {
		unshift @_, 1;
		my %td = task_data @_;
		my $otd = $db{$td{id}};
		if ($otd and not $td{desc}) {
			$td{desc} = $otd->{desc};
		}
		$db{$td{id}} = \%td;
	},

	todo => sub {
		unshift @_, 0;
		my %td = task_data @_;
		print STDERR "$0: todo: $td{id}: id already exists\n" and exit -1 if $db{$td{id}};
		$db{$td{id}} = \%td;
	},

	list => sub {
		my $opt = shift || "todo";
		print STDERR "$0: list: $opt: unknown option\n" and exit -1 unless (grep /^$opt$/, ("todo", "all"));
		for my $id (keys %db) {
			my %td = %{$db{$id}};
			print ":$id\t$td{desc}\n" unless ($opt eq "todo") and $td{complete};
		}
	},

	drop => sub {
		my $id = shift;
		$id =~ s/^://;
		die "No such id" unless $db{$id};
		delete $db{$id};
	},
);

my $cmd = shift @ARGV;
print STDERR "$0: $cmd: unknown command\n" and exit -1 unless $commands{$cmd};
$commands{$cmd}(@ARGV);

# Write task database
open DB, ">$dbfname" or die $!;
for my $id (keys %db) {
	my %e = %{$db{$id}};
	my $desc = $e{desc};
	$desc =~ s/\t/ /g;
	print DB "$e{complete}\t:$id\t$desc\n";
}
close DB or die $!;

# And close the lock.
close LOCK or die $!;


