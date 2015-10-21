#!/usr/bin/perl
use strict;
use warnings;

print "Adding courier-ldap authldap.schema...\n";

system("cp courier-ldap/authldap.schema /etc/ldap/schema/");

my $ldapconffolder = "/tmp/ldapConfig/";
if ( !-d $ldapconffolder ) { mkdir $ldapconffolder or die "Error creating directory: $ldapconffolder"; }
system("cp courier-ldap/schema_include.conf $ldapconffolder");

my $conffile = $ldapconffolder."schema_include.conf";
system("slaptest -f $conffile -F $ldapconffolder");
system ("ls -l $ldapconffolder");

print "\nYou can now edit file $ldapconffolder\.cn=config/cn=schema/cn={*}authldap.ldif\n";
print "Add ,cn=schema,cn=config to first line\n";
print "Remove the 7 last lines\n";
print "Run then: ldapadd -Y EXTERNAL -H ldapi:// -f /tmp/ldapConfig/cn=config/cn=schema/cn={4}authldap.ldif\n";
print "Check with: ldapsearch -Y EXTERNAL -H ldapi:// -b \"cn=schema,cn=config\" -LLL \"(objectClass=*)\" cn\n";

