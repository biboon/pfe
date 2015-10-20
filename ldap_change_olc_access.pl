#!/usr/bin/perl
use strict;
use warnings;

print "Changing ldap olcAccess\n";

system("ldapmodify -c -Y EXTERNAL -H ldapi:/// -f ldif/changeOlcAccess.ldif");

print "\nTrying to access ldap directory as anonymous...\n";
print "-----------------------------------------------\n";
system("ldapsearch -x -c -h localhost -b dc=airslip,dc=xyz");

print "\nTrying to access directory now as admin...\n";
print "-----------------------------------------------\n";
system ("ldapsearch -c -h localhost -b dc=airslip,dc=xyz -D \"cn=admin, dc=airslip,dc=xyz\" -W");
