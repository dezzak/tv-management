#!/usr/bin/perl
use strict;
use warnings;
use TV::Renamer;
use Data::Dumper;

# test script
my @test_files = (
	{
		filename          => 'Casualty_Series_29_-_9._Entrenched_b04nyv34_default.mp4',
		programme_name    => 'Casualty',
		series            => 29,
		episode           => 9,
		episode_title     => 'Entrenched',
		expected_filename => 'Casualty 29x09 - Entrenched.mp4',
		expected_dir      => '/foo/bar/Casualty/Casualty 29x/',
	},
	{
		filename          => 'Prime_Ministers_Questions_-_20_11_2013_b03jp4vy_default.mp4',
		programme_name    => 'Prime Ministers Questions',
		series            => undef,
		episode           => undef,
		episode_title     => '20 11 2013',
		expected_filename => 'Prime Ministers Questions - 20 11 2013.mp4',
		expected_dir      => '/foo/bar/Prime Ministers Questions/',
	},
	{
		filename          => 'Sherlock_Series_1_-_2._The_Blind_Banker_b00tc6t2_default.mp4',
		programme_name    => 'Sherlock',
		series            => 1,
		episode           => 2,
		episode_title     => 'The Blind Banker',
		expected_filename => 'Sherlock 1x02 - The Blind Banker.mp4',
		expected_dir      => '/foo/bar/Sherlock/Sherlock 1x/',
	},
	{
		filename          => 'Waterloo_Road_Series_10_-_Episode_4_b04nyk9y_default.mp4',
		programme_name    => 'Waterloo Road',
		series            => 10,
		episode           => 4,
		episode_title     => undef,
		expected_filename => 'Waterloo Road 10x04.mp4',
		expected_dir      => '/foo/bar/Waterloo Road/Waterloo Road 10x/',
	},
	{
		filename          => 'Waterloo_Road_Series_10_-_Episode_04_b04nyk9y_default.mp4',
		programme_name    => 'Waterloo Road',
		series            => 10,
		episode           => 4,
		episode_title     => undef,
		expected_filename => 'Waterloo Road 10x04.mp4',
		expected_dir      => '/foo/bar/Waterloo Road/Waterloo Road 10x/',
	},
	{
		filename          => 'White.Collar.S06E03.720p.HDTV.x264-KILLERS.mkv',
		programme_name    => 'White Collar',
		series            => 6,
		episode           => 3,
		episode_title     => undef,
		expected_filename => 'White Collar 6x03.mkv',
		expected_dir      => '/foo/bar/White Collar/White Collar 6x/',
	},
	{
		filename          => 'The.Mentalist.S06E18.720p.HDTV.X264-DIMENSION.mkv',
		programme_name    => 'The Mentalist',
		series            => 6,
		episode           => 18,
		episode_title     => undef,
		expected_filename => 'The Mentalist 6x18.mkv',
		expected_dir      => '/foo/bar/The Mentalist/The Mentalist 6x/',
	},
	{
		filename          => 'Greys.Anatomy.S11E07.720p.HDTV.X264-DIMENSION.mkv',
		programme_name    => "Grey's Anatomy",
		series            => 11,
		episode           => 7,
		episode_title     => undef,
		expected_filename => "Grey's Anatomy 11x07.mkv",
		expected_dir      => "/foo/bar/Grey's Anatomy/Grey's Anatomy 11x/",
	},
	{
		filename          => 'white.collar.s05e06.720p.hdtv.x264-killers.mkv',
		programme_name    => 'White Collar',
		series            => 5,
		episode           => 6,
		episode_title     => undef,
		expected_filename => 'White Collar 5x06.mkv',
		expected_dir      => '/foo/bar/White Collar/White Collar 5x/',
	},
	{
		filename          => 'Game.of.Thrones.S05E01.HDTV.x264-Xclusive.mp4',
		programme_name    => 'Game of Thrones',
		series            => 5,
		episode           => 1,
		episode_title     => undef,
		expected_filename => 'Game of Thrones 5x01.mp4',
		expected_dir      => '/foo/bar/Game of Thrones/Game of Thrones 5x/',
	},
	{
		filename          => 'Question_Time_-_2017-09-28_b096gxvg_original.mp4',
		programme_name    => 'Question Time',
		series            => undef,
		episode           => undef,
		episode_title     => '2017-09-28',
		expected_filename => 'Question Time - 2017-09-28.mp4',
		expected_dir      => '/foo/bar/Question Time/2017/',
	},
	{
		filename          => 'Call_the_Midwife_Series_8_-_03._Episode_3_b0c1x6qn_original.mp4',
		programme_name    => 'Call the Midwife',
		series            => 8,
		episode           => 3,
		episode_title     => 'Episode 3',
		expected_filename => 'Call the Midwife 8x03 - Episode 3.mp4',
		expected_dir      => '/foo/bar/Call the Midwife/Call the Midwife 8x/',
	},
	{
		filename          => 'Harry_Potter_A_History_of_Magic_-__b09d5n6b_original3.mp4',
		programme_name    => 'Harry Potter A History of Magic',
		series            => undef,
		episode           => undef,
		episode_title     => q{},
		expected_filename => 'Harry Potter A History of Magic.mp4',
		expected_dir      => '/foo/bar/Harry Potter A History of Magic/',
	}
);

my $config_ref = {
	tv_base_directory => '/foo/bar/',
};

my $renamer = TV::Renamer->new($config_ref);

foreach my $test_ref (@test_files) {
	my $info = $renamer->get_programme_info($test_ref->{filename});
	my $pass = 1;
	foreach my $key (keys %{$test_ref}) {
		next if ($key eq 'filename');
		next if ($key eq 'expected_filename');
		next if ($key eq 'expected_dir');

		if (defined($test_ref->{$key})) {
			if (
				! defined($info->{$key})
				|| $test_ref->{$key} ne $info->{$key}
			) {
				$pass = 0;
			}
		}
		else {
			if (defined($info->{$key})) {
				$pass = 0;
			}
		}
	}

	my $given_filename = $renamer->get_normalised_filename($test_ref->{filename});
	if ($given_filename ne $test_ref->{expected_filename}) {
		$pass = 0;
		print '[FAIL] ' . $given_filename . "\n";
	}

	my $given_dir = $renamer->get_destination_directory_from_file($test_ref->{filename});
	if (
		! defined($given_dir)
		|| $given_dir ne $test_ref->{expected_dir}
	) {
		$pass = 0;
		print "[FAIL] With destination dir:\n";
		print Dumper($given_dir);
	}

	if ($pass) {
		print '[PASS] ' . $test_ref->{filename} . ' -> ' . $given_dir . $given_filename . "\n";
	}
	else {
		print Dumper($test_ref, $info);
	}
}
