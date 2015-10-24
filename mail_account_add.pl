#!/usr/bin/perl
use strict;
use warnings;

print "Let's add an user to the LDAP database\n";

print "Domain of the LDAP DB: ";
my $domain = readline(*STDIN);
chomp($domain);
print "Tld of the LDAP DB: ";
my $tld = readline(*STDIN);
chomp($tld);
print "Username\@$domain.$tld: ";
my $username = readline(*STDIN);
chomp($username);
print "First name: ";
my $firstname = readline(*STDIN);
chomp($firstname);
print "Last name: ";
my $name = readline(*STDIN);
chomp($name);

print "Password: ";
system("stty -echo");
my $password = readline(*STDIN);
system("stty echo");
chomp($password);
print "\n";
open my $in, "slappasswd -s $password -h {SSHA} |";
my $hash = <$in>;
close($in);

my $mailadd = $username."\@".$domain.".".$tld;

print "Adding entry $mailadd\n";

my $folder = "ldif";
my $filename = $folder."/new_entry.ldif";
if ( !-d $folder ) { mkdir $folder or die "Error creating directory: $folder"; }
open(my $fd, '>', $filename);

print $fd "dn:cn=$username,dc=mailAccount,dc=mail,dc=$domain,dc=$tld\n";
print $fd "uid:$username\n";
print $fd "mail:$mailadd\n";
print $fd "sn: $name\n";
print $fd "givenName: $firstname\n";
print $fd "displayName: $firstname $name\n";
print $fd "mailbox: $domain.$tld/$username/\n";
print $fd "homeDirectory: /home/vmail/\n";
print $fd "objectClass: top\n";
print $fd "objectClass: inetOrgPerson\n";
print $fd "objectClass: CourierMailAccount\n";
print $fd "userPassword: $hash\n";

close $fd;

system("ldapadd -D \"cn=admin,dc=$domain,dc=$tld\" -W -h localhost -f $filename");
#unlink $filename;
