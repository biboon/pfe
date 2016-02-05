#!/usr/bin/perl

use File::Copy;
use Intimail;

# ----

# Some variables
my $INTMP = "/tmp/in.$$";
my $JSONTMP = "/tmp/newmail.json.$$";
my $USERDATA = "/home/vmail/userdata/";
my $MAILBASE = "/home/vmail/";
my $MIMETMP = "/tmp/mime/";
my $LOGFILE = "/var/log/intimail/json_parser.log";
my $EXECFOLDER = "/home/moth/Documents/pfe/postfix/";
my $MINSIZE = 4;
my $RETRIES = 6; # Number of retries
my $SLEEPTIME = 1; # Initial sleep time in seconds
my $LDAPPW = `cat /etc/ldap/ldap.pw`; chomp $LDAPPW;

# Parse some arguments
my $queueid = $ARGV[0];
my $size = $ARGV[1];
my $from = $ARGV[2];

# Get the recipients array
my @recipients = ();
foreach $argnum (3 .. $#ARGV) {
	push @recipients, $ARGV[$argnum];
}

# Open log file
open(my $logfiled, '>>', $LOGFILE) or die "Could not open file $LOGFILE\n";

# Get stdin to tmp file
open(my $intmpd, '>', $INTMP) or die "Could not open file $INTMP\n";
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
open(my $jsontmpd, '>', $JSONTMP) or die "Could not open file $JSONTMP\n";
print $jsontmpd "\t\"from\": \"$from\",\n";
print $jsontmpd "\t\"subject\": \"$subject\",\n";
print $jsontmpd "\t\"timestamp\": \"$date\",\n";
print $jsontmpd "\t\"unixtimestamp\": \"$unixdate\",\n";
print $jsontmpd "\t\"queueid\": \"$queueid\",\n";
print $jsontmpd "\t\"size\": \"$size\",\n";
print $jsontmpd "\t\"status\": \"0\"\n";
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
				$id = (length $id && $id =~ m/\D*(\d*).*/) ? $1 + 1 : 0;

				# Parse the MIME file received to extract attachments
				mkdirp($MIMETMP, "0777");
				move($filelist, "$MIMETMP/$unixdate.$queueid");
				my $munpack = `munpack -t -C $MIMETMP $unixdate.$queueid`;
				my @lines = split /\n/, $munpack;
				my $misshtml = 1; my $pj = 0;
				foreach my $line( @lines ) {
					my ($mimefile, $mimetype);
					if ($line =~ m/([^ ]*) \((.*)\)/) { # Get the file and the type
						$mimefile = $1;
						$mimetype = $2;
						print $logfiled "Processing file $line > $MIMETMP$mimefile $mimetype\n";
						chmod 0770, "$MIMETMP$mimefile";
						if ($mimetype =~ m/text\/plain/ && $misshtml) { # Get plain text format unless we have html
							move("$MIMETMP$mimefile", "$USERDATA$domaintld/$mailbox/inbox/$unixdate.$queueid");
						} elsif ($mimetype =~ m/text\/html/) { # Get html file
							move("$MIMETMP$mimefile", "$USERDATA$domaintld/$mailbox/inbox/$unixdate.$queueid");
							$misshtml = 0;
						} else { # Get other files (attachments)
							my $pjfld = "$USERDATA$domaintld/$mailbox/inbox/$unixdate.$queueid.pj/";
							if (not -d $pjfld) { mkdirp($pjfld, "0770"); }
							move("$MIMETMP$mimefile", "$pjfld$mimefile");
							$pj++;
						}
					}
				}

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
						print $jsonmlbxtmp "\t\"to\": \"$address\",\n";
						print $jsonmlbxtmp "\t\"pj\": \"$pj\",\n";
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
#unlink $JSONTMP, $INTMP, $JSONTMP.$mailbox; # Gotta remove MIMETMP/ here
#deldir $MIMETMP;

exit 0;
