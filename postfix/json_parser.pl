#!/usr/bin/perl

use File::Copy;
use File::Basename;

# ----

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

# ----

# Some variables
my $INTMP = "/tmp/in.$$";
my $JSONTMP = "/tmp/newmail.json.$$";
my $USERDATA = "/home/vmail/userdata/";
my $MAILBASE = "/home/vmail/";
my $LOGFILE = "/var/log/intimail/json_parser.log";
my $EXECFOLDER = "/home/moth/Documents/pfe/postfix/";
my $MINSIZE = 4;
my $RETRIES = 6; # Number of retries
my $SLEEPTIME = 1; # Initial sleep time in seconds
my $LDAPPW = `cat /etc/ldap/ldap.pw`; chomp $LDAPPW;

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
open(my $logfiled, '>>', $LOGFILE) or die "Could not open file $LOGFILE\n";
open(my $jsontmpd, '>', $JSONTMP) or die "Could not open file $JSONTMP\n";
open(my $intmpd, '>', $INTMP) or die "Could not open file $INTMP\n";

# Get stdin to tmp file
while (<STDIN>) { print $intmpd $_; }
close $intmpd;

# Let's get some info to write in the json file
my $date = `date +%F\\ %T`;
my $unixdate = `date -d \"$date\" +%s`;
my $subject = `grep Subject: $INTMP | sed 's/Subject: \\(.*\\)/\\1/'`;
chomp $date; chomp $unixdate; chomp $subject;
if (not(defined $subject and length $subject)) { $subject = "(No Subject)"; }
print $logfiled "$date Starting json_parser/pid:$$\n";

# Writing the base of the new json info
print $jsontmpd "\t\"from\": \"$from\",\n";
print $jsontmpd "\t\"subject\": \"$subject\",\n";
print $jsontmpd "\t\"timestamp\": \"$date\",\n";
print $jsontmpd "\t\"unixtimestamp\": \"$unixdate\",\n";
print $jsontmpd "\t\"queueid\": \"$queueid\",\n";
print $jsontmpd "\t\"size\": \"$size\",\n";
print $jsontmpd "\t\"status\": \"0\",\n";
print $jsontmpd "\t\"pj\": \"0\",\n";
close $jsontmpd;

# Create some folders
#  Create usedata folder with right permissions

while ($RETRIES > 0 && scalar @recipients > 0) {
	
	for my $index (0 .. $#recipients) {
		my $address = $recipients[$index];
		print $logfiled "Doing recipient $address\n";
	
		my $tmp = $address;
		my ($mailbox, $domaintld) = ($tmp =~ m/([^@]+)@([^@]+)/);
		my ($domain, $tld) = ($domaintld =~ m/([^\.]+)\.([^\.]+)/);

		# Create user folders if needed userdata/domain.tld/
		my $JSONFOLDER = "$USERDATA$domaintld/$mailbox/json/";
		if (not -d $JSONFOLDER) {
			mkdirp($JSONFOLDER, "0770");
			copy("${EXECFOLDER}empty.json", "${JSONFOLDER}inbox.json");
		}

		# Get the original mail file path
		my $MAILBOXFOLDER = "$MAILBASE$domaintld/$mailbox/new/";
		my $filelist = `grep -rli $queueid $MAILBOXFOLDER`; chomp $filelist;
		if (length $filelist && `echo "$filelist" | wc -l` == 1) {
		
			# Get quota levels
			my $quota = `ldapsearch -D \"cn=admin,dc=$domain,dc=$tld\" -w $LDAPPW -b \"dc=people,dc=mail,dc=$domain,dc=$tld\" \"(mail=$address)\" | grep quota`;
			($quota) = ($quota =~ m/\D*(\d*)/);
			my $usedquota = (-e "${JSONFOLDER}quota.json") ? `cat ${JSONFOLDER}quota.json` : 0;
			chomp $usedquota;

			# Check if there is enough space
			$size = $size + $usedquota;
			if ($size < $quota) { # There is enough space available, process mail
				open(my $quotajson, '>', "${JSONFOLDER}quota.json") or die "Could not open file ${JSONFOLDER}quota.json\n";
				print $quotajson "$size";
				close $quotajson;
				chmod 0770, "${JSONFOLDER}quota.json";

				# Get the ID
				my $id = `grep \\"id\\" ${JSONFOLDER}inbox.json | head -n 1`;
				print $logfiled "Got id $id\n";
				$id = (length $id && $id =~ m/\D*(\d*).*/) ? $1 + 1 : 0;
				print $logfiled "Using id \#$id\n";

				# Let's finish writing json temporary file
				open(my $jsonmlbx, '<', "${JSONFOLDER}inbox.json") or die "Could not open file ${JSONFOLDER}inbox.json\n";
				open(my $jsontmpd, '<', $JSONTMP) or die "Could not open file $JSONTMP\n";
				open(my $jsonmlbxtmp, '>', "$JSONTMP.$mailbox") or die "Could not open file $JSONTMP.$mailbox\n";

				# Insert new json info to the file
				while (<$jsonmlbx>) {
					print $jsonmlbxtmp $_;
					if ($_ eq "[\n") {
						print $jsonmlbxtmp "{\n";
						print $jsonmlbxtmp "\t\"id\": \"$id\",\n";
						print $jsonmlbxtmp "\t\"to\": \"$address\"\n";
						while (<$jsontmpd>) {
							print $jsonmlbxtmp $_;
						}
						print $jsonmlbxtmp (($id != 0) ? "},\n" : "}\n");
					}
				}

				close $jsonmlbx;
				close $jsontmpd;
				close $jsonmlbxtmp;

				# Move json and mail files to the userdata folder and set permissions
				move("$JSONTMP.$mailbox", "${JSONFOLDER}inbox.json");
				# Create inbox folder if necessary
				if (not -d "$USERDATA$domaintld/$mailbox/inbox/") {
					mkdirp("$USERDATA$domaintld/$mailbox/inbox/", "0770");
				}
				move($filelist, "$USERDATA$domaintld/$mailbox/inbox/$unixdate.$queueid");
				chmod 0770, "${JSONFOLDER}inbox.json", "$USERDATA$domaintld/$mailbox/inbox/$unixdate.$queueid";

			} else { # There is not enough space, we delete the file
				print $logfiled "Not enough space, removing $filelist\n";
				unlink $filelist;
			}
	
			# Remove the processed address from the recipient list
			splice(@recipients, $index, 1);
			$index--;
	
		} else {
			print $logfiled "Could not find a single mail file with id $queueid\n";
		}
	}
	
	sleep $SLEEPTIME;
	$RETRIES--;
	$SLEEPTIME *= 2;
}

# Close files
close $logfiled;

# Remove temporary files
unlink $JSONTMP, $INTMP, $JSONTMP.$mailbox;

exit 0;
