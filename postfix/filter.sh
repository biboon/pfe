#!/bin/bash

# Simple shell based filter script
# See http://www.postfix.org/FILTER_README.html for more info
# Supposed to be invoked as /path/to/script -f sender recipients


INSPECT_DIR=/home/vmail/filter
SENDMAIL="/usr/sbin/sendmail -G -i" # Don't use -t here
PARSER=/home/moth/Documents/pfe/postfix/json_parser.sh

# Exit codes from <sysexits.h>
EX_TEMPFAIL=75
EX_UNAVAILABLE=69

#touch /tmp/filter

# Clean up when done or aborting
trap "rm -f in.$$" 0 1 2 3 15

# Start processing
cd $INSPECT_DIR || {
	echo $INSPECT_DIR does not exists; exit $EX_TEMPFAIL; }

cat > in.$$ || {
	echo Cannot save mail to file; exit $EX_TEMPFAIL; }

$PARSER "$@" < in.$$ || {
	echo Message content rejected; exit $EX_UNAVAILABLE; }

$SENDMAIL "$@" < in.$$

exit $?
