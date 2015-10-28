#!/usr/bin/perl


use IO::Socket;
use IO::Select;

use constant TIMEOUT => 10;

my $sock = IO::Socket::INET->new(PeerAddr=>"localhost:smtp(25)")
or die "cannot reach the server";

my $select = IO::Select->new($sock);
my $status = 0;

while ($status != -1) {
	if ($select->can_read(TIMEOUT)) {
		$sock->recv($data, 1024);
		#next if (length($data) < 2); # Empty data
		print "srv> $data"; #for verbosity
		@lines = split(/\n/, $data);
		foreach $fline (@lines) {
			print "lines> $fline";
		}
	}
}

$sock->send("quit\n");

