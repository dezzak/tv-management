#!/usr/bin/perl
# Monitor transmission for videos we can work with and move them if necessary
use strict;
use warnings;
use Getopt::Long;
use Carp;
use English qw(-no_match_vars);
use Config::Tiny;
use Cwd;
use Transmission::Client;

use Data::Dumper;

my $dir_sep = q{/};

# @todo - set these up as readonly consts
# From line 1855 of https://trac.transmissionbt.com/browser/trunk/libtransmission/transmission.h
my $TR_STATUS_STOPPED       = 0; # Torrent is stopped (not necessarily complete)
my $TR_STATUS_CHECK_WAIT    = 1; # Queued to check files
my $TR_STATUS_CHECK         = 2; # Checking files
my $TR_STATUS_DOWNLOAD_WAIT = 3; # Queued to download
my $TR_STATUS_DOWNLOAD      = 4; # Downloading
my $TR_STATUS_SEED_WAIT     = 5; # Queued to seed
my $TR_STATUS_SEED          = 6; # Seeding

# Initialise command line options to default
my $verbose     = 0;
my $config_file = undef;

GetOptions(
    'verbose'         => \$verbose,
    'configuration=s' => \$config_file,
);

my $config = get_configuration($config_file);

my $tv_manager        = $config->{_}->{tv_manager_path};

# Check config
if ( ! $tv_manager) {
    croak('Invalid configuration');
}

# Check transmission specific config

my $rpc_url      = $config->{transmission}->{rpc_url};
my $rpc_username = $config->{transmission}->{rpc_username};
my $rpc_password = $config->{transmission}->{rpc_password};
my $rpc_timeout  = $config->{transmission}->{rpc_timeout};

if ( ! $rpc_url || ! $rpc_username || ! $rpc_password) {
    croak('Invalid transmisison configuration');
}

my $client = Transmission::Client->new(
    url      => $rpc_url,
    username => $rpc_username,
    password => $rpc_password,
    timeout  => $rpc_timeout,
    autodie  => 1,
);

my @all_torrents = $client->read_torrents();

for my $torrent (@all_torrents) {
    my $torrent_name = $torrent->name;
    if ($torrent_name =~ m{
            S     # The letter S
            \d{2} # Two digits
            E     # The letter E
            \d{2} # Two digits
        }xms
    ) {
        verbose('Torrent "' . $torrent_name . '" matched on name');
        # Now check status - If seeding or waiting to seed, download has finished
        if ($torrent->status == $TR_STATUS_SEED_WAIT || $torrent->status == $TR_STATUS_SEED) {
            process_downloaded($torrent);
        }
        elsif ($torrent->status == $TR_STATUS_STOPPED) {
            # It has stopped, but might not be done seeding
            if ($torrent->upload_ratio >= 1 && $torrent->done_date) {
                process_fully_seeded($torrent);
            }
            else {
                verbose('Torrent stopped but not complete');
            }
        }
        else {
            verbose('Torrent still downloading');
        }
    }
    else {
        verbose('Failed to match torrent "' . $torrent_name . '" on name');
    }
}

sub process_fully_seeded {
    my ($torrent) = @_;
    verbose('Processing a torrent that has finished seeding');

    my @eligible_files = get_eligible_files($torrent);

    if ( ! @eligible_files) {
        verbose('Found no eligible files');
        return;
    }
    for my $file (@eligible_files) {
        # @ todo there'll be a bug here in that every time this is run, a new symlink to unwatched will be created, even
        # if we've already watched it. Perhaps we need to keep a list of what we've put there
        my $command = $tv_manager
                    . ' --move-file'
                    . ' --add-to-unwatched';
        if (defined $config_file) {
            $command .= ' --configuration ' . $config_file;
        }
        $command .= q{ "} . $file . q{"};
        verbose('Running following command: ' . $command);
        system $command;
    }

    # Then remove the torrent
    my %params = (
        ids => ($torrent->id),
        delete_local_data => 1,
    );
    $client->remove(%params);

    return;
}

sub process_downloaded {
    my ($torrent) = @_;
    verbose('Processing a torrent that has downloaded but not done seeding');

    my @eligible_files = get_eligible_files($torrent);

    if ( ! @eligible_files) {
        verbose('Found no eligible files');
        return;
    }
    for my $file (@eligible_files) {
        # @ todo there'll be a bug here in that every time this is run, a new symlink to unwatched will be created, even
        # if we've already watched it. Perhaps we need to keep a list of what we've put there
        my $command = $tv_manager
                    . ' --hardlink-file'
                    . ' --add-to-unwatched';
        if (defined $config_file) {
            $command .= ' --configuration ' . $config_file;
        }
        $command .= q{ "} . $file . q{"};
        verbose('Running following command: ' . $command);
        system $command;
    }

    return;
}

sub get_eligible_files {
    my ($torrent) = @_;

    my @eligible_files;

    my $torrent_base_dir = $torrent->download_dir;

    my $files = $torrent->files;
    my @files = @{$files};

    FILE:
    for my $file (@files) {
        my $filename = $file->name;

        # We don't care about any "Sample" directories
        if ($filename =~ m{
                $dir_sep # a directory seperator
                sample   # The word Sample
                $dir_sep # a directory seperator
            }xmis
        ) {
            verbose('Skipping sample file ' . $filename);
            next FILE;
        }

        if ($filename =~ m{
            \.      # A dot
            (
                mkv # Then the letters mkv
            )
            \Z      # Then the end of string
            }xms
        ) {
            verbose('Found file ' . $filename);
            push @eligible_files, $torrent_base_dir . $dir_sep . $filename;
        }
    }
    return @eligible_files;
}

sub usage {
    my $usage = << '_END_USAGE_';
Usage:
torrent_monitor

Scans for torrents that look like TV shows and when they are fully downloaded
hardlinks them to the TV directory. When they are complete, removes the
torrent and data files

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

  [transmission]
    rpc_url
      URL for transmission rpc

    rpc_username
      username for RPC access

    rpc_password
      password for RPC access

    rpc_timeout
      number of seconds to wait for a response from server

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
