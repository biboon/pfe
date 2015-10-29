#!/usr/bin/perl


use IO::Socket;
use IO::Select;
use Switch;

use constant TIMEOUT => 0.1;

my $sock = IO::Socket::INET->new(PeerAddr=>"localhost:smtp(25)")
or die "cannot reach the server";

my $select = IO::Select->new($sock);
my ($status, $code) = (0, 0);

while ($status >= 0) {
	if ($select->can_read(TIMEOUT)) {
		print $status;
		$sock->recv($data, 1024);
		#next if (length($data) < 2); # Empty data
		print "srv> $data"; #for verbosity
		@lines = split(/^/, $data);
		foreach $fline (@lines) {
			$fline =~ m/([0-9]{3})[ \-].*/;
			$code = $1;
			if (($status == 0 && $code != "220") ||
			    ($status == 1 && $code != "250") ||
			    ($status == 2 && $code != "250") ||
			    ($status == 3 && $code != "250") ||
			    ($status == 4 && $code != "354") ||
			    ($status == 5 && $code != "250")) {
				$status = -1;
			}				
		}

		switch ($status) {
			case 0 { print "ehlo intimail.pw\n"; $sock->send("ehlo intimail.pw\n"); $status++; }
			case 1 { print "mail from:jvaljean\@intimail.pw\n"; $sock->send("mail from:jvaljean\@intimail.pw\n"); $status++; }
			case 2 { print "rcpt to:r.libaert\@gmail.com\n"; $sock->send("rcpt to:r.libaert\@gmail.com\n"); $status++; }
			case 3 { print "data\n"; $sock->send("data\n"); $status++; }
			case 4 {
				open(my $fd, "mailtest.txt")
				or die "Could not open file";
				while (my $row = <$fd>) {
					chomp $row;
					$sock->send("$row\n");
					print "$row\n";
				}
				close $fd;
				$status++;
			}
			case 5 { print "quit\n"; $sock->send("quit\n"); $status == -2; }
			else { print "case value incorrect: $status, exiting"; $status = -1; }
		}
	}
}

$sock->send("quit\n");

