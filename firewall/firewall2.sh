#!/bin/sh

# -t filter is default so no need
# more info on iptables on http://www.thegeekstuff.com/2011/06/iptables-rules-examples/

# Last Revision
echo '=== Mur de Feu Ruleset v1.0 stable, Rev 20151026.05 ===\n'

HTTP_PORT=80
HTTPS_PORT=443
DNS_PORT=53
NTP_PORT=123
SMTP_PORT=25
POP3_PORT=110
IMAP_PORT=143

echo "Press any key to write Ruleset..."
read key

# Ne pas casser les connexions etablies
echo 'Maintaining already established connections...'
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Début du filtrage des ports
echo 'Filtering ports...'

# ICMP (Ping)
echo 'Allowing ICMP...'
iptables -A INPUT -i eth0 -p icmp -j ACCEPT

# HTTP + HTTPS
echo 'Allowing incoming HTTP and HTTPS traffic ('$HTTP_PORT','$HTTPS_PORT')...'
iptables -A INPUT -i eth0 -p tcp --dport $HTTP_PORT -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --dport $HTTPS_PORT -m state --state NEW,ESTABLISHED -j ACCEPT

# DNS
echo 'Allowing incoming DNS connections ('$DNS_PORT')...'
iptables -A INPUT -i eth0 -p tcp --dport $DNS_PORT -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i eth0 -p udp --dport $DNS_PORT -m state --state NEW,ESTABLISHED -j ACCEPT

# NTP
echo 'Allowing NTP connections ('$NTP_PORT')...'
iptables -A INPUT -i eth0 -p udp --dport $NTP_PORT  -m state --state NEW,ESTABLISHED -j ACCEPT

# SMTP
echo 'Allowing SMTP connexions ('$SMTP_PORT')...'
iptables -t filter -A INPUT -p tcp --dport $SMTP_PORT -j ACCEPT

# POP3
echo 'Allowing POP3 connexions ('$POP3_PORT')...'
iptables -t filter -A INPUT -p tcp --dport $POP3_PORT -j ACCEPT

# IMAP
echo 'Allowing IMAP connexions ('$IMAP_PORT')...'
iptables -t filter -A INPUT -p tcp --dport $IMAP_PORT -j ACCEPT

# DDOS Protection
echo 'Enforcing DDOS Protection...\n'
iptables -A INPUT -p tcp --dport $HTTP_PORT -m limit --limit 25/minute --limit-burst 100 -j ACCEPT

echo 'All done ! Press any key to quit...'
read key
