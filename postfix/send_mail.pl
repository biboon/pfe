#!/usr/bin/perl


use IO::Socket;
use IO::Select;
use Switch;
use Getopt::Std;

use constant TIMEOUT => 0.1;

#--- Checking options first ---#

my %options=();
getopts("vs:d:f:", \%options);

if (!($options{s} && $options{d} && $options{f})) {
	die "Usage: $0 [-v] -s sender -d destination -f mail file";
}

my $sender = $options{s};
my $dest = $options{d};
my $mailfile = $options{f};

$sender =~ s/\@/\\\@/g;
$dest =~ s/\@/\\\@/g;

#--- Finished, sending mail ---#

my $sock = IO::Socket::INET->new(PeerAddr=>"localhost:smtp(25)")
or die "cannot reach the server";
my $select = IO::Select->new($sock);

my ($status, $code) = (0, 0);
my $tosend = "";

while ($status >= 0) {
	if ($select->can_read(TIMEOUT)) {
		if ($options{v}) { print "state: $status\n"; }
		$sock->recv($data, 1024);
		#next if (length($data) < 2); # Empty data
		if ($options{v}) { print "srv> $data"; }
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
			case 1 { $tosend = "mail from:$sender"; }
			case 2 { $tosend = "rcpt to:$dest"; }
			case 3 { $tosend = "data"; }
			case 4 {
				open(my $fd, $mailfile)
				or die "Could not open file $mailfile";
				while (my $row = <$fd>) {
					chomp $row;
					$sock->send("$row\n");
					if ($options{v}) { print "$row\n"; }
				}
				close $fd;
			}
			case 5 { $tosend = "quit"; }
			case 6 { $status = -2; }
			else { print "case value incorrect: $status, exiting"; $status = -1; }
		}

		if ($status >= 0 && $status < 6) {
			if ($status != 4) {
				$sock->send("$tosend\n");
				if ($options{v}) { print "$tosend\n"; }
			}
			$status++;
		}
	}
}

if ( $status == -1) { $sock->send("quit\n"); }

