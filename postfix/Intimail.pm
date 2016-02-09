#!/usr/bin/perl

package Intimail;
use Exporter;
@ISA = ('Exporter');
@EXPORT = ('mkdirp', 'deldir', 'findptrn', 'parsemime');

use File::Basename;
use File::Copy;

# Works like the mkdir -p bash command, with a permission parameter
sub mkdirp ($$) {
    my ($dir, $perm) = (@_);
    return if (-d $dir);
    mkdirp(dirname($dir), $perm);
    my $old = umask;
    umask 0000;
    mkdir $dir, oct($perm);
    umask $old;
}

# Deletes a directory and all its content, like rm -r
# The path needs a trailing /, otherwise there will be strange behaviour
sub deldir ($) {
    my $dir = shift;
    chop $dir;
    opendir(my $dirfh, $dir) or die "Cannot open directory $dir\n";
    my @files = readdir $dirfh;
    foreach my $file( @files ) {
        chomp($file);
        if (not($file eq ".." || $file eq ".")) {
            if (-d "$dir/$file") { deldir("$dir/$file"); }
            else { unlink "$dir/$file"; }
        }
    }
    closedir $dirfh;
    rmdir $dir;
}

# Finds patterns in file and returns lines in an array
sub findptrn ($$) {
	my ($file, $pattern) = (@_);
	my @res = ();
	open (my $fh, '<', $file);
	while (<$fh>) {
		push @res, $_ if (index($_, $pattern) != -1);
	}
	return @res;
}

# Parses the mime type file and sets data in the /tmp/mime.$$/ folder
sub parsemime ($$) {
	my ($file, $MIME) = (@_);
	my @parts = ();
	my $OUTFLD = "${MIME}out/";
	my $MUNPACK = `which munpack`; chomp $MUNPACK;

	mkdir $MIME;
	mkdir $OUTFLD;
	move($file, "${MIME}mime");
	my $unpack = `$MUNPACK -t -C $MIME mime`;
	my @lines = split /\n/, $unpack;
	my $misshtml = 1;
	foreach my $line( @lines ) {
		if ($line =~ m/([^ ]*) \((.*)\)/) { # Get the file and the type
			my ($mfile, $mtype) = ($1, $2);
			chmod 0660, "$MIME$mfile";
			if ($mtype =~ m/text\/plain/ && $misshtml) { # Get plain text format unless we have html
				move("$MIME$mfile", "${OUTFLD}msg");
			} elsif ($mtype =~ m/text\/html/) { # Get html file
				move("$MIME$mfile", "${OUTFLD}msg");
				$misshtml = 0;
			} else { # Get other files (attachments)
				move("$MIME$mfile", "${OUTFLD}$mfile");
				push @parts, $mfile;
			}
		}
	}
	return @parts;
}

1;

