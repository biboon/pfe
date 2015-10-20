#!/usr/bin/perl
use strict;
use warnings;

print "Adding initial entries to the ldap directory\n";
print "Domain: ";
my $domain = readline(*STDIN);
print "Tld: ";
my $tld = readline(*STDIN);
print "Organization: ";
my $org = readline(*STDIN);

chomp($domain);
chomp($tld);
chomp($org);

print "Adding entries for $domain.$tld, org: $org\n";

my $folder = "ldif";
my $filename = $folder."/ldap_initial_entries.ldif";
if ( !-d $folder ) { mkdir $folder or die "Error creating directory: $folder"; }
open(my $fd, '>', $filename);

print $fd "dn: dc=$domain,dc=$tld\n";
print $fd "objectClass: dcObject\n";
print $fd "objectClass: organization\n";
print $fd "o: $org\n";
print $fd "dc: $domain\n";
print $fd "dn: cn=Manager,dc=$domain,dc=$tld\n";
print $fd "objectClass: organizationalRole\n";
print $fd "cn: Manager\n";

close $fd;

print "Running ldapadd...\n";
system("ldapadd -x -D \"cn=Manager,dc=$domain,dc=$tld\" -W -f $filename");
