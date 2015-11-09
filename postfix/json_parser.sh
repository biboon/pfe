#!/bin/bash

# Simple json parser script
# Supposed to be called by the filter.sh script
# Current parameters $@ = $queue_id $size $sender $recipient

INTMP=/tmp/in.$$
JSONTMP=/tmp/newmail.json.$$
JSONBASE=/home/vmail/json/
MINSIZE=4

# Exit codes from <sysexits.h>
EX_TEMPFAIL=75
EX_UNAVAILABLE=69

#touch /tmp/json_parser

# Clean up when done or aborting
trap "rm -f /tmp/*.$$" 0 1 2 3 15

QUEUEID=$1
shift

SIZE=$1
shift

FROM=$1
shift

cat > $INTMP || {
	echo Cannot save mail to file; exit $EX_TEMPFAIL; }


# Let's parse the data
#DATE=`grep Date: $INTMP | sed 's/Date: \(.*\)/\1/'`
DATE=`date +%F\ %T`
UNIXDATE=`date -d "$DATE" +%s`

unset SUBJECT
SUBJECT=`grep Subject: $INTMP | sed 's/Subject: \(.*\)/\1/'`
if [ -z "$SUBJECT" ]
then
	SUBJECT="(No Subject)"
fi


# Writing some tmp files
echo '{' >> $JSONTMP
echo -e "\t\"from\": \"$FROM\"," >> $JSONTMP
echo -e "\t\"subject\": \"$SUBJECT\"," >> $JSONTMP
echo -e "\t\"timestamp\": \"$DATE\"," >> $JSONTMP
echo -e "\t\"unixtimestamp\": \"$UNIXDATE\"," >> $JSONTMP
echo -e "\t\"queueid\": \"$QUEUEID\"," >> $JSONTMP
echo -e "\t\"size\": \"$SIZE\"," >> $JSONTMP
echo -e "\t\"status\": \"0\"," >> $JSONTMP
echo -e "\t\"pj\": \"0\"," >> $JSONTMP


# Create the directory if it doesn't exists
if [ ! -d $JSONBASE ]
then
	mkdir -p $JSONBASE
	chmod g=rx $JSONBASE
fi


# At this state, $@ is the array of recipient addresses
for param in "$@"
do
	unset MAILBOX
	unset DOMAIN
	unset ID
	unset FOLDER

	# Get the folder to write in
	MAILBOX=`echo $param | cut -f1 -d@`
	DOMAIN=`echo $param | cut -f2 -d@`
	if [ -z "$MAILBOX" -o -z "$DOMAIN" ]
	then
		echo Syntax error in recipients list; exit $EX_TEMPFAIL;
	fi
	
	# Create the folders if needed and assign rights
	FOLDER=${JSONBASE}${DOMAIN}/${MAILBOX}/
	if [ ! -d ${JSONBASE}${DOMAIN} ]
	then
		mkdir ${JSONBASE}${DOMAIN}
		chmod g=rx ${JSONBASE}${DOMAIN}
	fi
	if [ ! -d $FOLDER ]
	then
		mkdir $FOLDER
		chmod g=rx $FOLDER
	fi

	# Create inbox.json
	if [ ! -f ${FOLDER}inbox.json ]
	then
		echo '[' >> ${FOLDER}inbox.json
		echo ']' >> ${FOLDER}inbox.json
		chmod g=rx ${FOLDER}inbox.json
	fi
	# Set initial id in case inbox.json is empty
	if [ `wc -l ${FOLDER}inbox.json | cut -f1 -d\ ` -lt $MINSIZE ]
	then
		ID=0
	fi
	
	# GET THE ID MUDAFUGA
	if [ -z "$ID" ]
	then
		ID=`cat ${FOLDER}inbox.json | grep \"id\" | head -n 1 | sed 's/.*\"\([0-9]*\)\".*/\1/g'`
		ID=$(($ID + 1))
	fi

	# Let's finish to write the info before inserting into json
	echo -e "\t\"id\": \"$ID\"," >> $JSONTMP
	echo -e "\t\"to\": \"$param\"" >> $JSONTMP
	if [ $ID -ne 0 ]
	then
		echo "}," >> $JSONTMP
	else
		echo '}' >> $JSONTMP
	fi
	
	sed -i "/\[/r $JSONTMP" ${FOLDER}inbox.json
done

