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
			if ($test_ref->{$key} ne $info->{$key}) {
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
	if ($given_dir ne $test_ref->{expected_dir}) {
		$pass = 0;
		print '[FAIL] ' . $given_dir . "\n";
	}

	if ($pass) {
		print '[PASS] ' . $test_ref->{filename}. "\n";
	}
	else {
		print Dumper($test_ref, $info);
	}
}
