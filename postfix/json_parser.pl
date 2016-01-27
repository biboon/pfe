#!/bin/perl

my $INTMP = "/tmp/in.$$";
my $JSONTMP = "/tmp/newmail.json.$$";
my $USERDATA = "/home/vmail/userdata/";
my $MAILBASE = "/home/vmail/";
my $LOGFILE = "/var/log/intimail/json_parser.log";
my $MINSIZE = 4;
my $RETRIES = 8; # Number of retries
my $SLEEPTIME = 1; # Initial sleep time in seconds
my $LDAPPW = `cat /etc/ldap/ldap.pw`;

# Exit codes from <sysexits.h>
my $EX_TEMPFAIL = 75;
my $EX_UNAVAILABLE = 69;
my $EX_CANTCREAT = 73;

# Parse some arguments
my $queueid = $ARGV[0];
my $size = $ARGV[1];
my $from = $ARGV[2];

# Get the recipients array
my @recipients = ();
foreach $argnum (3 .. $#ARGV) {
	push @recipients, $ARGV[$argnum];
}

# Open some files
open(my $logfiled, '>', $LOGFILE) or die;
open(my $jsontmpd, '>', $JSONTMP) or die;
open(my $intmpd, '>', $INTMP) or die;

# Get stdin to tmp file
while (<STDIN>) { print $intmpd $_; }
close $intmpd;

# Let's get some info to write in the json file
my $date = `date +%F\\ %T`;
my $unixdate = `date -d \"$date\" +%s`;
my $subject = `grep Subject: $INTMP | sed 's/Subject: \\(.*\\)/\\1/'`;
chomp $date; chomp $unixdate; chomp $subject;
if (not(defined $subject and length $subject)) { $subject = "(No Subject)"; }
print $logfiled "$date Starting json_parser/pid:$$ using arguments $@\n";

# Writing the base of the new json info
print $jsontmpd "{\n" or die;
print $jsontmpd "\t\"from\": \"$from\",\n";
print $jsontmpd "\t\"subject\": \"$subject\",\n";
print $jsontmpd "\t\"timestamp\": \"$date\",\n";
print $jsontmpd "\t\"unixtimestamp\": \"$unixdate\",\n";
print $jsontmpd "\t\"queueid\": \"$queueid\",\n";
print $jsontmpd "\t\"size\": \"$size\",\n";
print $jsontmpd "\t\"status\": \"0\",\n";
print $jsontmpd "\t\"pj\": \"0\",\n";

# Create some folders
#  Create usedata folder with right permissions

while ($RETRIES > 0 && scalar @recipients > 0) {
	foreach $address (@recipients) {
		print $logfiled "Doing recipient $address\n";
	}

	$RETRIES--;
}

# Close files
close $logfiled;
close $jsontmpd;

