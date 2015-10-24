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

print $fd "dn: dc=mailAccount,dc=mail,dc=$domain,dc=$tld\n";
print $fd "description: All mail accounts\n";
print $fd "o: mailAccount\n";
print $fd "dc: mailAccount\n";
print $fd "objectClass: dcObject\n";
print $fd "objectClass: organization\n\n";

print $fd "dn: dc=mailAlias,dc=mail,dc=$domain,dc=$tld\n";
print $fd "description: All mail aliases\n";
print $fd "o: mailAlias\n";
print $fd "dc: mailAlias\n";
print $fd "objectClass: dcObject\n";
print $fd "objectClass: organization\n\n";

print $fd "dn: dc=users,dc=mailAccount,dc=mail,dc=$domain,dc=$tld\n";
print $fd "description: Normal users\n";
print $fd "o: users\n";
print $fd "dc: users\n";
print $fd "objectClass: dcObject\n";
print $fd "objectClass: organization\n\n";

print $fd "dn: dc=administrators,dc=mailAccount,dc=mail,dc=$domain,dc=$tld\n";
print $fd "description: Users with administrator privileges\n";
print $fd "o: administrators\n";
print $fd "dc: administrators\n";
print $fd "objectClass: dcObject\n";
print $fd "objectClass: organization\n\n";

close $fd;

system("ldapadd -D \"cn=admin,dc=$domain,dc=$tld\" -W -h localhost -f $filename");
#unlink $filename; #deletes the temporary file
