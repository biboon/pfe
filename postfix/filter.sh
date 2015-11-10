#!/bin/bash

# Simple shell based filter script
# See http://www.postfix.org/FILTER_README.html for more info
# Supposed to be invoked as /path/to/script -f sender recipients


INTMP=/tmp/in.$$
SENDMAIL="/usr/sbin/sendmail -G -i" # Don't use -t here
PARSER=/home/moth/Documents/pfe/postfix/json_parser.sh

# Exit codes from <sysexits.h>
EX_TEMPFAIL=75
EX_UNAVAILABLE=69

#touch /tmp/filter

# Clean up when done or aborting
trap "rm -f /tmp/*.$$" 0 1 2 3 15

# Start processing
cat > $INTMP || {
	echo Cannot save mail to file; exit $EX_TEMPFAIL; }

$PARSER "$@" < $INTMP || {
	echo Message content rejected; exit $EX_UNAVAILABLE; }

# Remove size and queueid before sending the mail
# Check postfix's main.cf before modifying anything here
shift
shift
SENDER=$1
shift
$SENDMAIL -f $SENDER -- "$@" < $INTMP

exit $?
