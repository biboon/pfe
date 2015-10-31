echo 'Current status of servers :'
eval service postfix status
eval service lighttpd status
eval service slapd status
eval service saslauthd status
eval service bind9 status
eval service ntp status
eval service ssh status
eval service iptablesd status
echo 'You may start a service via using "service <name> start"'
