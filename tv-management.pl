#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use TV::Renamer;
use File::Spec;
use File::Basename;
use File::Path qw(make_path);
use File::Copy;
use Carp;
use English qw(-no_match_vars);
use Cwd;

# @todo: Move these to a config file
my $base_tv_dir   = '/tmp/TV';
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
my $target_filename  = $renamer->get_normalised_filename($filename);
my $target_full_path = $target_directory . $target_filename;

if ( ! $target_directory || ! $target_filename) {
	croak('Unable to get TV information for ' .$filename);
}

verbose('Target directory: ' . $target_directory);
verbose('Target filename: ' . $target_filename);

# Make any directories that we need
verbose('Creating target directory (if needed)');
make_path($target_directory);

# What do we want to do?
if ($move_file) {
	do_move($target_full_path, $full_filepath);
}
elsif ($hardlink_file) {
	do_hardlink($target_full_path, $full_filepath);
}


if ($add_to_unwatched) {
	add_to_unwatched($target_full_path, $target_filename);
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

sub do_hardlink {
	my ($target_path, $origin_path) = @_;
	verbose('Starting hardlink file logic');
	# See if the file already exists
	if ( -e $target_path) {
		# The file already exists, but don't panic yet, it might be the same
		#  inode in which case we don't have to do anything
		if ((stat $target_path)[1] == (stat $origin_path)[1]) {
			# Same inode
			verbose('Files are already the same inode - no moving to do');
		}
		else {
			my $message = 'A file already exists at the target location: ';
			$message .= $target_path;
			croak($message);
		}
	}
	else {
		# Try to create a new link there - may fail if on different filesystem
		verbose('Creating link');
		my $result = link $origin_path, $target_path;
		if ($result) {
			verbose('Link created');
		}
		else {
			my $message = $OS_ERROR . "\n";
			$message .= 'Unable to create link to target location. ';
			$message .= 'Is it the same FS?: ' . $target_path;
			croak($message);
		}
	}
	return;
}

sub do_move {
	my ($target_path, $origin_path) = @_;
	verbose('Starting move file logic');
	# See if the file already exists
	if ( -e $target_path) {
		# The file already exists, but don't panic yet, it might be the same
		#  inode in which case we simply move the original
		if ((stat $target_path)[1] == (stat $origin_path)[1]) {
			# Same inode - remove original
			verbose('Target exists as same file - Removing original');
			my $result = unlink $origin_path;
			if ($result) {
				verbose('Original removed');
			}
			else {
				my $message = $OS_ERROR . "\n";
				$message .= 'Unable to remove original file: '. $target_path;
				croak($message);
			}
		}
		else {
			my $message = 'A file already exists at the target location: ';
			$message .= $target_path . "\n";
			croak($message);
		}
	}
	else {
		# Try to move the file
		verbose('Moving file');
		my $result = move($origin_path, $target_path);
		if ($result) {
			verbose('File moved');
		}
		else {
			my $message = $OS_ERROR . "\n";
			$message .= 'Unable to move file to destination: '. $target_path;
			croak($message);
		}
	}
	return;
}

sub add_to_unwatched {
	my ($new_filename, $link_filename) = @_;
	verbose('Adding to unwatched');
	# We need to try and make the symlink relative, so that it works properly
	# regardless of mountpoint. hardlink might be better here, but the
	# existing solution is a symlink one.
	my $relative_path = File::Spec->abs2rel($new_filename, $unwatched_dir);
	verbose('Calculated relative path as ' . $relative_path);

	verbose('Creating symlink');
	my $dir_sep = q{/};
	my $symlink_filename = $unwatched_dir . $dir_sep . $link_filename;

	my $result = symlink $relative_path, $symlink_filename;
	if ($result) {
		verbose('link created');
	}
	else {
		my $message = $OS_ERROR . "\n";
		$message .= 'Unable to create symlink: ' . $symlink_filename;
		croak($message);
	}
	return;
}
