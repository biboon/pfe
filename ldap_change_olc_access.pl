#!/usr/bin/perl
use strict;
use warnings;

print "Changing ldap olcAccess\n";
print "Domain of the LDAP directory: ";
my $domain = readline(*STDIN);
chomp($domain);
print "Tld of the LDAP directory: ";
my $tld = readline(*STDIN);
chomp($tld);

my $folder = "ldif";
my $filename = $folder."/changeOlcAccess.ldif";
if ( !-d $folder ) { mkdir $folder or die "Error creating directory: $folder"; }
open(my $fd, '>', $filename);

print $fd "dn: olcDatabase={1}hdb,cn=config\n";
print $fd "changetype: modify\n";
print $fd "delete: olcAccess\n";
print $fd "-\n";
print $fd "add: olcAccess\n";
print $fd "olcAccess: {0}to attrs=userPassword,shadowLastChange by self write by anonymous auth by dn=\"cn=admin,dc=$domain,dc=$tld\" write by * none\n";
print $fd "-\n";
print $fd "add: olcAccess\n";
print $fd "olcAccess: {1}to dn.base=\"\" by * read\n";
print $fd "-\n";
print $fd "add: olcAccess\n";
print $fd "olcAccess: {2}to * by self write by dn=\"cn=admin,dc=$domain,dc=$tld\" write by * none\n";
print $fd "-\n";

close $fd;
print "Written file $filename\n\n";

system("ldapmodify -c -Y EXTERNAL -H ldapi:/// -f ldif/changeOlcAccess.ldif");

print "\nTrying to access ldap directory as anonymous...\n";
print "-----------------------------------------------\n";
system("ldapsearch -x -c -h localhost -b dc=$domain,dc=$tld");

print "\nTrying to access directory now as admin...\n";
print "-----------------------------------------------\n";
system ("ldapsearch -c -h localhost -b dc=$domain,dc=$tld -D \"cn=admin,dc=$domain,dc=$tld\" -W");
