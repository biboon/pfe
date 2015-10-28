#!/usr/bin/perl
use strict;
use warning;

use IO::Socket;
use IO::Select;
use MIME::Base64;

my $sock = IO::Socket::INET->new(LocalAddr => 'localhost', LocalPort=>25, Proto => 'tcp')
or die "cannot reach the server";

my $select = IO::Select->new($sock);
my $status = 0;

while ($status != -1) {
        if (@ready = $select->can_read(0.1)) {
                foreach $fd (@ready) {
                        $sock->recv($data, 1024);
                        next if (length($data) < 2);
                        print $data;
                        # Looking for a PRIVMSG from Candy
                        if ($data =~ m/password/) { $status = -1; }
                        elsif ($data =~ m/:.* PRIVMSG roberta :(.*)/) {
                                print "This was our message: $1\n";
                                my $decoded = decode_base64($1);
                                $sock->send("PRIVMSG Candy :!ep2 -rep $decoded\n");
                        }
                }
        }

        if ($status == 0) { $sock->send("NICK roberta\n"); $status++; }
        elsif ($status == 1) { $sock->send("USER roberta 8 * :gneeeh\n"); $status++; }
        elsif ($status == 2) { sleep 2; $sock->send("JOIN #root-me_challenge\n"); $status++; }
        elsif ($status == 3) { $sock->send("PRIVMSG Candy :!ep2\n"); $status++; }
}

$sock->send("QUIT\n");

