#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Carp;
use English qw(-no_match_vars);
use Config::Tiny;
use Cwd;

my $dir_sep = q{/};

# Initialise command line options to default
my $verbose     = 0;
my $config_file = undef;

GetOptions(
    'verbose'         => \$verbose,
    'configuration=s' => \$config_file,
);

my $config = get_configuration($config_file);

my $tv_manager  = $config->{_}->{tv_manager_path};
my $iplayer_dir = $config->{_}->{iplayer_dir};

# Check config
if ( ! $tv_manager || ! $iplayer_dir) {
    croak('Invalid configuration');
}

my $result = opendir D, $iplayer_dir;
if ( ! $result) {
    croak('Failed to open iplayer directory: ' . $OS_ERROR);
}
while (my $file = readdir D) {
    if ($file =~ /(default|original)(\.flv|\.mp4)$/xms) {
        verbose('Found file ' . $file);
        my $command = $tv_manager
                    . ' --move-file'
                    . ' --add-to-unwatched';
        if (defined $config_file) {
            $command .= ' --configuration ' . $config_file;
        }
        $command .= sprintf ' "%s"', $iplayer_dir . $dir_sep . $file;
        verbose('Running following command: ' . $command);
        system $command;
    }
}
closedir(D);

sub usage {
    my $usage = << '_END_USAGE_';
Usage:
iplayer_rename

Scans for files in the iplayer folder that have finished downloading and moves
them to the right place then adds them to the unwatched list

Additional options:

  --verbose
    Display verbose debugging output

  --configuration filename
    Use the specified configuration. If omitted, will look for a file called
    .tv-management.ini in the current directory or the user's home folder

Configuration:

  A simple ini file with the following settings

  tv_manager_path
    Path to the tv-management executable

  iplayer_dir
    Directory to scan for iplayer content

_END_USAGE_

    print $usage;
    return;
}

# @todo - not sure if the below can be moved to a common location before we
# know paths. Perhaps we need a package for this stuff
sub verbose {
    my ($message) = @_;
    if ($verbose) {
        print $message . "\n";
    }
    return;
}

sub get_configuration {
    my ($conf_file) = @_;
    if ( ! defined $conf_file) {
        $conf_file = get_default_config_file();
        if ( ! defined $conf_file) {
            my $message = 'Unable to find a config file to use';
            usage();
            croak($message);
        }
    }
    verbose('Using config file: ' . $conf_file);

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
        if ( -e $filename) {
            return $filename;
        }
    }
    return;
}
