#!/usr/bin/perl


use IO::Socket;
use IO::Select;
use Switch;

use constant TIMEOUT => 0.1;

my $sock = IO::Socket::INET->new(PeerAddr=>"localhost:smtp(25)")
or die "cannot reach the server";
my $select = IO::Select->new($sock);

my ($status, $code) = (0, 0);
my $tosend = "";

while ($status >= 0) {
	if ($select->can_read(TIMEOUT)) {
		print "state: $status\n";
		$sock->recv($data, 1024);
		#next if (length($data) < 2); # Empty data
		print "srv> $data"; #for verbosity
		@lines = split(/^/, $data);
		foreach $fline (@lines) {
			$fline =~ m/([0-9]{3})[ \-].*/;
			$code = $1;
			if ((($status == 1 || $status == 2 || $status == 3 || $status == 5) && $code != "250")
			 || ($status == 0 && $code != "220")
			 || ($status == 4 && $code != "354")
			 || ($status == 6 && $code != "221")) {
				$status = -1;
			}				
		}

		switch ($status) {
			case 0 { $tosend = "ehlo intimail.pw"; }
			case 1 { $tosend = "mail from:jvaljean\@intimail.pw"; }
			case 2 { $tosend = "rcpt to:r.libaert\@gmail.com"; }
			case 3 { $tosend = "data"; }
			case 4 {
				open(my $fd, "mailtest.txt")
				or die "Could not open file";
				while (my $row = <$fd>) {
					chomp $row;
					$sock->send("$row\n");
					print "$row\n";
				}
				close $fd;
			}
			case 5 { $tosend = "quit"; }
			case 6 { $status = -2; }
			else { print "case value incorrect: $status, exiting"; $status = -1; }
		}

		if ($status >= 0 && $status < 6) {
			if ($status != 4) {
				print "$tosend\n";
				$sock->send("$tosend\n");
			}
			$status++;
		}
	}
}

if ( $status == -1) { $sock->send("quit\n"); }

