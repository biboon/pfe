#!/usr/bin/perl
use strict;
use warnings;

print "Let's build the initial mail tree in the LDAP directory\n";

print "Domain of the LDAP DB: ";
my $domain = readline(*STDIN);
chomp($domain);
print "Tld of the LDAP DB: ";
my $tld = readline(*STDIN);
chomp($tld);

my $folder = "ldif";
my $filename = $folder."/mail_tree.ldif";
if ( !-d $folder ) { mkdir $folder or die "Error creating directory: $folder"; }
open(my $fd, '>', $filename);

print $fd "dn: dc=mail,dc=$domain,dc=$tld\n";
print $fd "o: intimail.pw\n";
print $fd "description: Global mail tree\n";
print $fd "dc: mail\n";
print $fd "objectClass: dcObject\n";
print $fd "objectClass: organization\n\n";

print $fd "dn: dc=people,dc=mail,dc=$domain,dc=$tld\n";
print $fd "description: Informations of all users\n";
print $fd "o: people\n";
print $fd "dc: people\n";
print $fd "objectClass: dcObject\n";
print $fd "objectClass: organization\n\n";

print $fd "dn: dc=groups,dc=mail,dc=$domain,dc=$tld\n";
print $fd "description: All groups of users\n";
print $fd "o: groups\n";
print $fd "dc: groups\n";
print $fd "objectClass: dcObject\n";
print $fd "objectClass: organization\n\n";

close $fd;

system("ldapadd -D \"cn=admin,dc=$domain,dc=$tld\" -W -h localhost -f $filename");
#unlink $filename; #deletes the temporary file
