#!/usr/bin/perl
use strict;
my $dir = "/media/media/media/media/iplayer";
my $tv_base = "/media/media/media/media/TV";
my $unwatched = "/media/media/media/media/unwatched";
opendir(D, $dir) || die "Can't opedir: $!\n";
while (my $f = readdir(D)) {
    if ($f =~ /default(\.flv|\.mp4)$/) {
        my $extension = $1;
        my $programme;
        my $series = -1;
        my $episode = -1;
        my $title = -1;
        my $outfilename;
        my $out_dir;
        my $sym_dir;
        my $command;
        my @parts = split(/\_\-\_/, $f, 2);
        if ($parts[0] =~ /\_Series\_[0-9]+$/) {
            # We have a series. Get the programme and series number by splitting around _Series_
            ($programme, $series) = split(/\_Series\_/, $parts[0], 2);
            $programme =~ s/\_/ /g;
        } else {
            $programme = $parts[0];
            $programme =~ s/\_/ /g;
        }
        # Chop the dull stuff off the end
        my $endpart = $parts[1];
        $endpart =~ s/\_[a-z0-9]{8}\_default$extension//;
        if ($endpart =~ /^Episode\_([0-9]+)(.*)/) {
            # We have an Episode x format
            $episode = $1;
            $episode =~ s/^Episode\_//;
            if ($2) {
                $title = $2;
            }
        } elsif ($endpart =~ /^([0-9]+)\.(.*)/) {
            # We have a x. format
            $episode = $1;
            if ($2) {
                $title = $2;
            }
        } else {
            # No episode
            $title = $endpart;
        }
        $outfilename = $programme;
        if (!-d "$tv_base/$programme") {
            # Make the directory
            if (!mkdir "$tv_base/$programme") {
                print "Couldn't create directory $tv_base/$programme";
                next;
            }
        }
        $out_dir = "$tv_base/$programme";
        if ($series != -1) {
            $outfilename .= " " . $series . "x";
            if (!-d "$tv_base/$programme/$programme $series" . "x") {
                # Make the directory
                if (!mkdir "$tv_base/$programme/$programme $series" . "x") {
                    print "Couldn't create directory $tv_base/$programme/$programme $series" . "x";
                    next;
                }
            }
            $out_dir = "$tv_base/$programme/$programme $series" . "x";
        } else {
            $outfilename .= " ";
        }
        if ($episode != -1) {
            if ($episode <10) {
                $episode = '0' . $episode;
            }
            $outfilename .= $episode;
        }
        if ($title != -1) {
            $title =~ s/\_/ /g;
            $title =~ s/^\ //g;
            $outfilename .= " - " . $title;
        }
        $outfilename .= $extension;
        $outfilename =~ s/  / /g;
        if (rename($dir . "/$f", $out_dir . "/$outfilename")) {
            print "Moved $f to $outfilename\n";
            $sym_dir = $out_dir;
            $sym_dir =~ s/^$tv_base/\.\.\/TV/;
            $command = "ln -s \"$sym_dir/$outfilename\" \"$unwatched/$outfilename\"";
            system($command);
        } else {
            print "Failed moving $dir/$f to $out_dir/$outfilename\n";
        }
    }
}
closedir(D);
