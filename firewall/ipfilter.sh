#!/bin/sh

# -t filter is default so no need
# more info on iptables on http://www.thegeekstuff.com/2011/06/iptables-rules-examples/

WHITELIST=whitelist.txt
regexp='s/\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\).*/\1/p'
localnetwork=192.168.1.0/24

# Interdire toute connexion entrante et sortante
echo 'Dropping all traffic'
iptables -P INPUT DROP
iptables -P FORWARD DROP
# iptables -P OUTPUT DROP

# Ne pas casser les connexions etablies
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Accept everything from the 192.168.1.x network
#echo 'Accept traffic coming from the local network' $localnetwork
#iptables -A INPUT -i eth0 -s $localnetwork -j ACCEPT

# Accepting traffic from ip specified in whitelist
echo 'Accepting traffic from ips specified in the whitelist'
while read line
do
        [ -z "$line" ] && continue
        line=`echo $line | sed -ne $regexp`
        echo "Allowing ip $line..."
        iptables -A INPUT -i eth0 -s $line -j ACCEPT
done < $WHITELIST
