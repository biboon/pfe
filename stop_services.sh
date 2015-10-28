echo 'Stop services...'
eval service postfix stop
eval service lighttpd stop
eval service slapd stop
eval service saslauthd stop
eval service bind9 stop
echo 'Done, good night !'
