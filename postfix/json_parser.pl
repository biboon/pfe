#!/usr/bin/perl

use lib "/home/moth/Documents/pfe/postfix";

use File::Copy;
use Intimail;

# ----

# Some variables
my $TMPFLD = "/tmp/intiparse.$$/";
my $JSONTMP = "${TMPFLD}newmail.json.$$";
my $VMAIL = "/home/vmail/";
my $USERDATA = "${VMAIL}userdata/";
my $INTMP = "${TMPFLD}original";
my $LOGFILE = "/var/log/intimail/json_parser.log";
my $EXECFOLDER = "/home/moth/Documents/pfe/postfix/";
my $MINSIZE = 4;
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

# Create tmp folder
mkdirp($TMPFLD, "0770");

# Get stdin to tmp file
open(my $intmpd, '>', $INTMP) or die "Could not open file $INTMP\n";
while (<STDIN>) { print $intmpd $_; }
close $intmpd;

# Let's get some info to write in the json file
my $date = `date +%F\\ %T`;
my $unixdate = `date -d \"$date\" +%s`;
#my $subject = `grep Subject: $INTMP | sed 's/Subject: \\(.*\\)/\\1/'`;
my $subject = (findptrn($INTMP, "Subject:"))[0];
print $logfiled "ph1: $subject\n";
($subject) = ($subject =~ m/Subject: (.*)/);
print $logfiled "ph2: $subject\n";
chomp $date; chomp $unixdate; chomp $subject;
$subject = "(No Subject)" if (not(defined $subject and length $subject));
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

# Process mail
my @attachments = parsemime($INTMP, $TMPFLD);

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

	# Get quota levels
	my $quota = `ldapsearch -D \"cn=admin,dc=$domain,dc=$tld\" -w $LDAPPW -b \"dc=people,dc=mail,dc=$domain,dc=$tld\" \"(mail=$address)\" | grep quota`;
	($quota) = ($quota =~ m/\D*(\d*)/);
	my $usedquota = (-e "${JSONFOLDER}quota.json") ? `cat ${JSONFOLDER}quota.json` : 0; chomp $usedquota;

	# Check if there is enough space
	$size = $size + $usedquota;
	if ($size < $quota) { # There is enough space available, process mail
		open(my $quotajson, '>', "${JSONFOLDER}quota.json") or die "Could not open file ${JSONFOLDER}quota.json\n";
		print $quotajson $size;
		close $quotajson;
		chmod 0660, "${JSONFOLDER}quota.json";

		# Get the ID
		my $id = (findptrn("${JSONFOLDER}inbox.json", "\"id\""))[0];
		$id = (length $id && $id =~ m/\D*(\d*).*/) ? $1 + 1 : 0;

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
				print $jsonmlbxtmp "\t\"pj\": \"$#attachments\",\n";
				print $jsonmlbxtmp $_ while (<$jsontmpd>);
				print $jsonmlbxtmp (($id != 0) ? "},\n" : "}\n");
			}
		}
		close $jsonmlbx; close $jsontmpd; close $jsonmlbxtmp;
			
		# Move json and mail files to the userdata folder and set permissions
		move("$JSONTMP.$mailbox", "${JSONFOLDER}inbox.json");
		chmod 0660, "${JSONFOLDER}inbox.json";
			
		# Create inbox folder if necessary
		my $INBOXFLD = "$USERDATA$domaintld/$mailbox/inbox/";
		mkdirp($INBOXFLD, "0770") if (not -d $INBOXFLD);
			
		# Copy files to user folder
		copy("${TMPFLD}/out/msg", "$INBOXFLD$unixdate.$queueid");
		chmod 0660, "$INBOXFLD$unixdate.$queueid";
		mkdirp("$INBOXFLD$unixdate.$queueid.pj/", "0770") if (scalar @attachments > 0);
		foreach my $attach( @attachments ) {
			copy("${TMPFLD}/out/$attach", "$INBOXFLD$unixdate.$queueid.pj/$attach");
			chmod 0660, "$INBOXFLD$unixdate.$queueid.pj/$attach";
		}
			
	} else { # There is not enough space, we delete the file
		print $logfiled "Not enough space, removing $filelist\n";
	}

	# Remove the processed address from the recipient list
	splice(@recipients, $index, 1);
	$index--;
}

# Close files
close $logfiled;

# Remove temporary files
#deldir $MIMETMP;

exit 0;
