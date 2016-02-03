#!/bin/bash

# Simple shell based filter script
# See http://www.postfix.org/FILTER_README.html for more info
# Supposed to be invoked as /path/to/script -f sender recipients


INTMP=/tmp/in.$$
SENDMAIL="/usr/sbin/sendmail -G -i" # Don't use -t here
#PARSER=/home/moth/Documents/pfe/postfix/json_parser2.sh
PARSER=/home/moth/Documents/pfe/postfix/json_parser.pl
LOGFILE=/var/log/intimail/json_parser.log

# Exit codes from <sysexits.h>
EX_TEMPFAIL=75
EX_UNAVAILABLE=69

#touch /tmp/filter
#whoami >> /tmp/filter

# Clean up when done or aborting
trap "rm -f /tmp/*.$$" 0 1 2 3 15

# Start processing
cat > $INTMP || {
	echo Cannot save mail to file $INTMP >> $LOGFILE; exit $EX_TEMPFAIL; }

# Remove size and queueid before sending the mail
# Check postfix's main.cf before modifying anything here
SENDER=$3

$SENDMAIL -f $SENDER -- "${@:4}" < $INTMP || {
	echo Sendmail failed exit code $? >> $LOGFILE; exit $?; }

nohup $PARSER "$@" < $INTMP & >> $LOGFILE;

exit $?
