echo 'Starting services...'
eval service postfix start
eval service lighttpd start
eval service slapd start
eval service saslauthd start
eval service bind9 start
echo 'Done, off to work !'
