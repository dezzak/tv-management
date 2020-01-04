#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use File::Spec;
use File::Basename;
use File::Path qw(make_path);
use File::Copy;
use Carp;
use English qw(-no_match_vars);
use Config::Tiny;
use Cwd;
use Scalar::Util::Numeric qw(isint);

use lib dirname(__FILE__);
use TV::Renamer;

my $dir_sep = q{/};

# Initialise command line options to default
my $move_file        = 0;
my $hardlink_file    = 0;
my $add_to_unwatched = 0;
my $filename         = undef;
my $verbose          = 0;
my $config_file      = undef;

GetOptions(
    'move-file'        => \$move_file,
    'hardlink-file'    => \$hardlink_file,
    'add-to-unwatched' => \$add_to_unwatched,
    'verbose'          => \$verbose,
    'configuration=s'  => \$config_file,
);

$filename = shift @ARGV;

# Make sure that we can proceed
if ( ( !$move_file && !$hardlink_file ) || !$filename ) {
    usage();
    exit;
}

my $config = get_configuration($config_file);

my $base_tv_dir   = $config->{_}->{base_tv_dir};
my $unwatched_dir = $config->{_}->{unwatched_dir};

# Check config
if ( !$base_tv_dir || !$unwatched_dir ) {
    croak('Invalid configuration');
}

verbose('Resolving filename');
my $full_filepath = File::Spec->rel2abs($filename);
$filename = basename($full_filepath);

verbose( 'Working with filename: ' . $filename );

verbose('Loading Renamer module');
my $renamer = TV::Renamer->new( { tv_base_directory => $base_tv_dir } );
verbose('Loaded Renamer module');

my $target_directory =
    $renamer->get_destination_directory_from_file($filename);
my $target_filename  = $renamer->get_normalised_filename($filename);
my $target_full_path = $target_directory . $target_filename;

if ( !$target_directory || !$target_filename ) {
    croak( 'Unable to get TV information for ' . $filename );
}

verbose( 'Target directory: ' . $target_directory );
verbose( 'Target filename: ' . $target_filename );

# Make any directories that we need
verbose('Creating target directory (if needed)');
make_path($target_directory);

# What do we want to do?
if ($move_file) {
    do_move( $target_full_path, $full_filepath );
    set_file_permissions( $target_full_path );
}
elsif ($hardlink_file) {
    do_hardlink( $target_full_path, $full_filepath );
    set_file_permissions( $target_full_path );
}

if ($add_to_unwatched) {
    add_to_unwatched( $target_full_path, $target_filename );
}

sub usage {
    my $usage = << '_END_USAGE_';
Usage:
tv-management --move-file [--add-to-unwatched] filename

Move the given filename to the correct folder (and add a symlink to the unwatched folder)

tv-management --hardlink-file [--add-to-unwatched] filename

Hardlink the given filename to the correct folder (and add a symlink to the unwatched folder)

Additional options:

  --verbose
    Display verbose debugging output

  --configuration filename
    Use the specified configuration. If omitted, will look for a file called .tv-management.ini in the current directory
    or the user's home folder

Configuration:

  A simple ini file with the following settings

  base_tv_dir
    The directory where TV shows are permanently stored

  unwatched_dir
    A directory that new TV shows are symlinked to.

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
    my ( $target_path, $origin_path ) = @_;
    verbose('Starting hardlink file logic');

    # See if the file already exists
    if ( -e $target_path ) {

        # The file already exists, but don't panic yet, it might be the same
        #  inode in which case we don't have to do anything
        if ( ( stat $target_path )[1] == ( stat $origin_path )[1] ) {

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
    my ( $target_path, $origin_path ) = @_;
    verbose('Starting move file logic');

    # See if the file already exists
    if ( -e $target_path ) {
        verbose('File already exists at target path - trying to deduplicate');
        return deduplicate_files( $target_path, $origin_path );
    }
    # Try to move the file
    verbose('Moving file');
    return move_file($origin_path, $target_path);
}

sub deduplicate_files {
    my ( $target_path, $origin_path ) = @_;
    my @target_details = stat $target_path;
    my @origin_details = stat $origin_path;

    # The file already exists, but don't panic yet, it might be the same
    #  inode in which case we simply move the original
    if ( $target_details[1] == $origin_details[1] ) {

        # Same inode - remove original
        verbose('Target exists as same file - Removing original');
        return remove_file($origin_path);
    }

    my $modify_time_difference = $origin_details[9] - $target_details[9];
    verbose('modify time difference: ' . $modify_time_difference . 's');
    if ($modify_time_difference < 300) {
        verbose('Modification time difference is < 5mins, continuing with move');
        return move_file($origin_path, $target_path);
    }
    my $message = 'A file already exists at the target location: ';
    $message .= $target_path . "\n";
    croak($message);
}

sub remove_file {
    my ($path) = @_;
    verbose( 'Trying to remove file: ' . $path );
    my $result = unlink $path;
    if ($result) {
        verbose('File removed');
    }
    else {
        my $message = $OS_ERROR . "\n";
        $message .= 'Unable to remove file: ' . $path;
        croak($message);
    }
    return;
}

sub move_file {
    my ( $origin_path, $target_path ) = @_;
    verbose('Moving ' . $origin_path . ' to ' . $target_path);
    my $result = move( $origin_path, $target_path );
    if ($result) {
        verbose('File moved');
    }
    else {
        my $message = $OS_ERROR . "\n";
        $message .= 'Unable to move file to destination: ' . $target_path;
        croak($message);
    }
    return;
}

sub add_to_unwatched {
    my ( $new_filename, $link_filename ) = @_;
    verbose('Adding to unwatched');

    # We need to try and make the symlink relative, so that it works properly
    # regardless of mountpoint. hardlink might be better here, but the
    # existing solution is a symlink one.
    my $relative_path = File::Spec->abs2rel( $new_filename, $unwatched_dir );
    verbose( 'Calculated relative path as ' . $relative_path );

    verbose('Creating symlink');
    my $symlink_filename = $unwatched_dir . $dir_sep . $link_filename;

    if ( -e $symlink_filename ) {
        verbose('link already exists');
        return;
    }

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

sub get_configuration {
    my ($conf_file) = @_;
    if ( !defined $conf_file ) {
        $conf_file = get_default_config_file();
        if ( !defined $conf_file ) {
            my $message = 'Unable to find a config file to use';
            usage();
            croak($message);
        }
    }
    verbose( 'Using config file: ' . $conf_file );

    return Config::Tiny->read($conf_file);
}

sub get_default_config_file {
    verbose('Determining default config file');
    my $default_filename = '.tv-management.ini';

    # We default to current_dir/.tv-management.ini
    # Then ~/.tv-management.ini
    my $dir = getcwd;
    my @files_to_test;
    push @files_to_test, $dir . $dir_sep . $default_filename;
    push @files_to_test, $ENV{HOME} . $dir_sep . $default_filename;
    for my $filename (@files_to_test) {
        if ( -e $filename ) {
            return $filename;
        }
    }
    return;
}

sub set_file_permissions {
    my ( $file ) = @_;

    verbose('Changing mode of ' . $file);
    my $mode = $config->{_}->{file_permissions} || 0644;
    if ( !isint($mode) ) {
        $mode = oct($mode);
    }
    my $result = chmod $mode, $filename;
    if ($result) {
        verbose('Mode changed');
    }
    else {
        my $message = $OS_ERROR . "\n";
        $message .= 'Unable to change mode of ' . $filename;
        croak($message);
    }
    return;
}
