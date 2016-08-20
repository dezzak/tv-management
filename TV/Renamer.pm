#!/usr/bin/perl
use strict;
use warnings;
package TV::Renamer;

our $VERSION = '1.0';

# config should contain the following keys:
# - tv_base_directory
sub new {
    my ($class, $config_ref) = @_;
    my $self = bless {}, $class;

    $self->{config_ref} = $config_ref;

    $self->_init_base_directory();

    return $self;
}

sub get_destination_directory_from_file {
    my ($self, $filename) = @_;

    my $programme_info_ref = $self->get_programme_info($filename);

    if ( ! defined($programme_info_ref)) {
        return;
    }

    my $destination_directory = $self->{config_ref}->{tv_base_directory};

    $destination_directory .= q{/} . $programme_info_ref->{programme_name};

    if (defined($programme_info_ref->{series})) {
        $destination_directory .= q{/} . $programme_info_ref->{programme_name};
        $destination_directory .= q{ } . $programme_info_ref->{series} . 'x';
    }

    return $destination_directory . q{/};
}

sub get_normalised_filename {
    my ($self, $filename) = @_;

    my $programme_info_ref = $self->get_programme_info($filename);

    my $normalised_name = $programme_info_ref->{programme_name};

    if (defined($programme_info_ref->{series})) {
        $normalised_name .= q{ } . $programme_info_ref->{series} . 'x';
    }
    else {
        $normalised_name .= q{ };
    }

    if (defined($programme_info_ref->{episode})) {
        my $episode = $programme_info_ref->{episode};
        if ($episode < 10) {
            $episode = '0' . $programme_info_ref->{episode};
        }
        $normalised_name .= $episode;
    }

    if (defined($programme_info_ref->{episode_title})) {
        $normalised_name .= " - " . $programme_info_ref->{episode_title};
    }

    my $extension = $self->_get_extension($filename);
    $normalised_name .= $extension;

    # And tidy up
    $normalised_name =~ s/  / /g;

    return $normalised_name;
}

# Will return a hashref:
# - programme_name
# - series (can be undef)
# - episode (can be undef)
# - episode_title (can be undef)
sub get_programme_info {
    my ($self, $filename) = @_;

    # Try and split around " - " - this is how iplayer names its files
    if ($filename =~ m{
        _  # an underscore
        \- # followed by a dash
        _  # followed by another underscore
    }x) {
        return $self->_get_iplayer_programme_info($filename);
    }

    if ($filename =~ m{
            S     # The letter S
            \d{2} # Two digits
            E     # The letter E
            \d{2} # Two digits
        }xmsi
    ) {
        return $self->_get_torrent_programme_info($filename);
    }

    return;
}

sub _get_iplayer_programme_info {
    my ($self, $filename) = @_;

    my $programme_name;
    my $series;
    my $episode;
    my $episode_title;
    my $extension = $self->_get_extension($filename);

    my $programme_info_ref = {};
    # Try and split around " - " - this is how iplayer names its files
    my @filename_parts = split /\_\-\_/, $filename, 2;
    if ($filename_parts[0] =~ /\_Series\_[\d]+$/) {
        # We have a series. Get the programme and series number by splitting around _Series_
        ($programme_name, $series) = split /\_Series\_/, $filename_parts[0], 2;
        $programme_name =~ s/\_/ /g;
    }
    else {
        $programme_name = $filename_parts[0];
        $programme_name =~ s/\_/ /g;
    }
    # Chop the dull stuff off the end
    my $endpart = $filename_parts[1];
    $endpart =~ s/\_[\w]{8}\_(default|original|editorial)$extension//;

    if ($endpart =~ /^Episode\_([\d]+)(.*)/) {
        # We have an Episode x format
        $episode = $1;
        $episode =~ s/^Episode\_//;
        if ($2) {
            $episode_title = $2;
        }
    }
    elsif ($endpart =~ /^([\d]+)\.(.*)/) {
        # We have a x. format
        $episode = $1;
        if ($2) {
            $episode_title = $2;
        }
    }
    else {
        # No episode
        $episode_title = $endpart;
    }

    if ($episode_title) {
        $episode_title =~ s/\_/ /g;
        $episode_title =~ s/^\ //g;
    }


    $programme_info_ref->{programme_name} = $programme_name;
    $programme_info_ref->{series} = $series;
    $programme_info_ref->{episode} = $episode;
    $programme_info_ref->{episode_title} = $episode_title;

    return $programme_info_ref;
}

sub _get_torrent_programme_info {
    my ($self, $filename) = @_;

    my $programme_name;
    my $series;
    my $episode;
    my $episode_title;
    my $extension = $self->_get_extension($filename);

    if ($filename =~ m{
        \A       # The start of the filename
        (.*)     # Capture all characters
        s        # Up to the letter s
        (\d+)    # The capture 1 or more digits
        e        # Then the letter e
        (\d{2,}) # Then 2 or more digits
        }xmsi
    ) {
        my $captured_name    = $1;
        my $captured_series  = $2;
        my $captured_episode = $3;

        # Replace dots with spaces
        $captured_name =~ s/\./ /xmsg;
        # and trim
        $captured_name =~ s/\A\s+//xms;
        $captured_name =~ s/\s+\Z//xms;

        $programme_name = ucwords($captured_name, q{ });
        # Don't allow ucwords for some words though...
        my @always_lowercase = ('of');
        foreach my $word (@always_lowercase) {
            $programme_name =~ s/\b$word\b/$word/xmis;
        }

        # Remove leading zeros from series and episodes
        $series = $self->_to_number($captured_series);
        $episode = $self->_to_number($captured_episode);
    }
    else {
        verbose("Couldn't process $filename");
    }

    # Special case - Grey's Anatomy - add apostrophe
    if ($programme_name eq 'Greys Anatomy') {
        $programme_name = "Grey's Anatomy";
    }

    my $programme_info_ref = {};
    $programme_info_ref->{programme_name} = $programme_name;
    $programme_info_ref->{series} = $series;
    $programme_info_ref->{episode} = $episode;
    $programme_info_ref->{episode_title} = $episode_title;

    return $programme_info_ref;
}

sub _get_extension {
    my ($self, $filename) = @_;

    my $extension = q();

    if ($filename =~ /(\.[\w]{3})$/) {
        $extension = $1;
    }

    return $extension;
}

sub _init_base_directory {
    my $self = shift;

    # remove a trailing / from the base directory
    if ($self->{config_ref}->{tv_base_directory} =~ m{
        /$ # If it ends in a /
    }x
    ) {
        $self->{config_ref}->{tv_base_directory} =~ s|/$||x;
    }

    return;
}

sub _to_number {
    my ($self, $string) = @_;

    $string =~ s/\A0+//xms;

    return int $string;
}

sub ucwords {
    my($new, $delim) = @_;
    $new =~ s/($delim|^)(.*?)(?=$delim|$)/$1\u\L$2/sg;
    $new;
}

1;
