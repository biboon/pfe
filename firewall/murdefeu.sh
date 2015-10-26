#!/bin/sh

# -t filter is default so no need
# more info on iptables on http://www.thegeekstuff.com/2011/06/iptables-rules-examples/

# Nettoyage des règles
echo 'Cleaning up rules and clearing firewall...'
iptables -F
iptables -X
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Rejet de toutes les connexions par défaut
echo 'Dropping all incoming traffic...'
iptables -P INPUT DROP

# Ne pas casser les connexions etablies
echo 'Maintaining already established connections...'
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Autoriser le loopback
echo 'Allowing loopback interface...'
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Début du filtrage des ports
echo 'Filtering ports...'

# ICMP (Ping)
echo 'Allowing ICMP...'
iptables -A INPUT -i eth0 -p icmp -j ACCEPT
iptables -A OUTPUT -o eth0 -p icmp -j ACCEPT

# SSH (incoming)
echo 'Allowing incoming SSH connections (22)...'
iptables -A INPUT -i eth0 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# HTTP + HTTPS (incoming)
echo 'Allowing incoming HTTP and HTTPS traffic (80,443)...'
iptables -A INPUT -i eth0 -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 80 -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 443 -j ACCEPT

# DNS (incoming)
echo 'Allowing incoming DNS connections (53)...'
iptables -A INPUT -i eth0 -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -i eth0 -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -o eth0 -p udp --dport 53 -j ACCEPT

# NTP
echo 'Allowing NTP connections (123)...'
iptables -A INPUT -i eth0 -p udp --dport 123  -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 123 -m state --state ESTABLISHED -j ACCEPT

# SMTP
echo 'Allowing SMTP connexions (25)...'
iptables -t filter -A INPUT -p tcp --dport 25 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 25 -j ACCEPT

# POP3
echo 'Allowing POP3 connexions (110)...'
iptables -t filter -A INPUT -p tcp --dport 110 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 110 -j ACCEPT

# IMAP
echo 'Allowing IMAP connexions (143)...'
iptables -t filter -A INPUT -p tcp --dport 143 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 143 -j ACCEPT

# LDAP
echo 'Allowing LDAP connection only from localhost (389)...'
iptables -A INPUT -p tcp --dport 389 -s localhost -j ACCEPT
iptables -A INPUT -p tcp --dport 389 -j DROP
