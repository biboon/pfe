#!/usr/bin/perl

package Intimail;
use Exporter;
@ISA = ('Exporter');
@EXPORT = ('mkdirp', 'deldir', 'findptrn');

use File::Basename;

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

1;

