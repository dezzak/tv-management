tv-management
=============

# Intentions #

This is a package mainly for my own use, but others may find it useful. I receive tv programmes from a variety of
sources, each with their own specific needs, but there are three common problems I have.

- I need to know when there is something new
- I need to keep any temporary working directories clean
- I need to sort things into the correct folder automatically.

To address this, I shall use the following solutions.

## Knowing when there is something new ##

To do this, I have an "unwatched" folder which simply contains symlinks to other parts of the filesystem. When I've
watched something, I just remove the symlink.

## Keep working directories clean ##

When something has finished downloading, it should be moved. But some methods of downloading, such as torrents, still
need the files for a certain amount of time, such as for seeding. They should not be moved in these circumstances.

My plan for torrents is to use an API to the torrent server to see when something has finished downloading. If it has,
a hardlink will be created in the target destination folder, and a symlink to the target destination in the unwatched
folder. When the torrent has finished seeding the hardlink in the torrent working dir will then be removed. I chose not
to use a symlink between the target and working dirs as the target dir is often accessed over a samba share that can't
see this dir, and because I wouldn't want to do a move, create-symink-in-old-location as this may break transmission.

## Sort things into the correct folder ##

I have an existing script I use with get-iplayer that does this, which I shall adapt into a library to do most of the
work for this.

# Solution #

There will be four parts to my solution - a library for the sorting, a client that moves files, a transmission script
that keeps track of transmission and calls the client to do moving, and a get-iplayer script that does something similar

# client #

The client is intended to have the following synopsis:

    tv-management --move-file [--add-to-unwatched] filename
	
This will find the correct directory to move the given file to and move it there. If a file already exists with the
same name in the target directory, it will check if they are the same inode. If so it will simply remove _filename_.

The --add-to-unwatched flag will add a symlink in the unwatched folder.
	
	tv-management --hardlink-file [--add-to-unwatched] filename
	
This will create a hardlink of _filename_ in the determined target directory.