#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use TV::Renamer;
use File::Spec;
use File::Basename;
use File::Path qw(make_path);

use Data::Dumper;

# @todo: Move these to a config file
my $base_tv_dir = '/tmp/TV';
my $unwatched_dir = '/tmp/unwatched';
# End config

# Initialise command line options to default
my $move_file        = 0;
my $hardlink_file    = 0;
my $add_to_unwatched = 0;
my $filename         = undef;
my $verbose          = 0;

GetOptions(
	'move-file'        => \$move_file,
	'hardlink-file'    => \$hardlink_file,
	'add-to-unwatched' => \$add_to_unwatched,
	'verbose'          => \$verbose
);

$filename = shift @ARGV;

# Make sure that we can proceed
if (( ! $move_file && ! $hardlink_file) || ! $filename) {
	usage();
	exit;
}

verbose('Resolving filename');
my $full_filepath = File::Spec->rel2abs($filename);
$filename = basename($full_filepath);

verbose('Working with filename: ' . $filename);

verbose('Loading Renamer module');
my $renamer = TV::Renamer->new({tv_base_directory => $base_tv_dir});
verbose('Loaded Renamer module');

my $target_directory = $renamer->get_destination_directory_from_file($filename);
my $target_filename = $renamer->get_normalised_filename($filename);
my $target_full_path = $target_directory . $target_filename;

if ( ! $target_directory || ! $target_filename) {
	print STDERR 'Unable to get TV information for ' .$filename . "\n";
	exit;
}

verbose('Target directory: ' . $target_directory);
verbose('Target filename: ' . $target_filename);

# Make any directories that we need
verbose('Creating target directory (if needed)');
make_path($target_directory);

# What do we want to do?
if ($move_file) {
	verbose('Starting move file logic');
}
elsif ($hardlink_file) {
	verbose('Starting hardlink file logic');
	# See if the file already exists
	if ( -e $target_full_path) {
		# The file already exists, but don't panic yet, it might be the same
		#  inode in which case we don't have to do anything
		if ((stat $target_full_path)[1] == (stat $full_filepath)[1]) {
			# Same inode
			verbose('Files are already the same inode - no moving to do');
		}
		else {
			my $message = 'A file already exists at the target location: ';
			$message .= $target_full_path . "\n";
			print STDERR $message;
			exit;
		}
	}
	else {
		# Try to create a new link there - may fail if on different filesystem
		verbose('Creating link');
		my $result = link $full_filepath, $target_full_path;
		if ($result) {
			verbose('Link created');
		}
		else {
			my $message = 'Unable to create link to target location. ';
			$message .= 'Is it the same FS?: ' . $target_full_path . "\n";
			print STDERR $message;
			exit;
		}
	}
}

sub usage {
	my $usage = << '_END_USAGE_';
Usage:
tv-management --move-file [--add-to-unwatched] filename

Move the given filename to the correct folder (and add a symlink to the unwatched folder)

tv-management --hardlink-file [--add-to-unwatched] filename

Hardlink the given filename to the correct folder (and add a symlink to the unwatched folder)
_END_USAGE_

	print $usage;
	return;
}

sub verbose {
	my ($message) = @_;
	if ($verbose) {
		print $message . "\n";
	}
	return;
}
