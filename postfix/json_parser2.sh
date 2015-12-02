#!/bin/bash
# For debugging
#set -x
#rm /tmp/*.log
#exec 2>> /tmp/json.log
#whoami >> /tmp/user.log

# Simple json parser script
# Supposed to be called by the filter.sh script
# Current parameters $@ = $queue_id $size $sender $recipient

INTMP=/tmp/in.$$
JSONTMP=/tmp/newmail.json.$$
USERDATA=/home/vmail/userdata/
MAILBASE=/home/vmail/
MINSIZE=4
TIMEUP=5 # Timeout in minutes

# Exit codes from <sysexits.h>
EX_TEMPFAIL=75
EX_UNAVAILABLE=69
EX_CANTCREAT=73

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
echo '{' >> $JSONTMP || {
	echo Cannot write tmp json file; exit $EX_CANTCREAT; }
echo -e "\t\"from\": \"$FROM\"," >> $JSONTMP
echo -e "\t\"subject\": \"$SUBJECT\"," >> $JSONTMP
echo -e "\t\"timestamp\": \"$DATE\"," >> $JSONTMP
echo -e "\t\"unixtimestamp\": \"$UNIXDATE\"," >> $JSONTMP
echo -e "\t\"queueid\": \"$QUEUEID\"," >> $JSONTMP
echo -e "\t\"size\": \"$SIZE\"," >> $JSONTMP
echo -e "\t\"status\": \"0\"," >> $JSONTMP
echo -e "\t\"pj\": \"0\"," >> $JSONTMP


# Create the directory if it doesn't exist
if [ ! -d $USERDATA ]
then
	mkdir $USERDATA || {
		echo Cannot create folder $USERDATA; exit $EX_CANTCREAT; }
	chmod g=rwx $USERDATA
fi


# At this state, $@ is the array of recipient addresses
# We copy all the recipients to another array
RECIPIENTS=("$@")

while [ $TIMEOUT -gt 0 ];
do

	for (( index=0; index<${#RECIPIENTS[@]}; index++))
	do
		unset MAILBOX
		unset DOMAIN
		unset JFOLDER
		unset ID

		# Get the folder to write in
		MAILBOX=`echo $param | cut -f1 -d@`
		DOMAIN=`echo $param | cut -f2 -d@`
		if [ -z "$MAILBOX" -o -z "$DOMAIN" ]
		then
			echo Syntax error in recipients list; exit $EX_TEMPFAIL;
		fi
	
		# Create the folders if needed and assign rights
		if [ ! -d ${USERDATA}${DOMAIN} ]
		then
			mkdir ${USERDATA}${DOMAIN} || {
				echo Cannot create folder; exit $EX_CANTCREAT; }
			chmod g=rwx ${USERDATA}${DOMAIN}
		fi
		JFOLDER=${USERDATA}${DOMAIN}/${MAILBOX}/json/
		if [ ! -d $JFOLDER ]
		then
			mkdir -p $JFOLDER || {
				echo Cannot create folder; exit $EX_CANTCREAT; }
			chmod -R g=rwx ${USERDATA}${DOMAIN}/${MAILBOX}
		fi
	
		# Create inbox.json
		if [ ! -f ${JFOLDER}inbox.json ]
		then
			echo '[' >> ${JFOLDER}inbox.json || {
				echo Cannot create file; exit $EX_CANTCREAT; }
			echo ']' >> ${JFOLDER}inbox.json
			chmod g=rwx ${JFOLDER}inbox.json
		fi

		# GET THE ID MUDAFUGA
		ID=`grep \"id\" ${JFOLDER}inbox.json | head -n 1 | sed 's/.*\"\([0-9]*\)\".*/\1/g'`
		if [ -z "$ID" ]
		then
			ID=$(($ID + 1))
		else
			ID=0
		fi

		#Try to get the filepath
		FOLDMAILBOX=${MAILBASE}${DOMAIN}/${MAILBOX}/
		FILELIST=`grep -ril $QUEUEID $FOLDERMAILBOX`
		if [ `wc -l "$FILELIST" | cut -f1 -d\ ` -eq 1 ]
		then
			FILEPATH=${FILELIST#*${FOLDMAILBOX}}
		else
			echo Seems like there is two mailfiles with the same queue ID
			continue
		fi

		# Let's copy and finish to write the info before inserting into json
		cp $JSONTMP ${JSONTMP}${MAILBOX}
		echo -e "\t\"id\": \"$ID\"," >> ${JSONTMP}${MAILBOX}
		echo -e "\t\"to\": \"$param\"" >> ${JSONTMP}${MAILBOX}

		if [ $ID -ne 0 ]
		then
			echo "}," >> ${JSONTMP}${MAILBOX}
		else
			echo '}' >> ${JSONTMP}${MAILBOX}
		fi
		RECIPIENTS=(${RECIPIENTS[@]:0:$index} ${RECIPIENTS[@]:$(($index + 1))})
		((index--))

		if [ ! -d ${USERDATA}${DOMAIN}/${MAILBOX}/inbox/ ]
		then
			mkdir ${USERDATA}${DOMAIN}/${MAILBOX}/inbox/ || {
				echo Cannot create folder; exit $EX_CANTCREAT; }
			chmod g=rwx ${USERDATA}${DOMAIN}/${MAILBOX}/inbox/
		fi
		mv $FILELIST ${USERDATA}${DOMAIN}/${MAILBOX}/inbox/${UNIXDATE}.${QUEUEID}
		chmod g=rwx ${USERDATA}${DOMAIN}/${MAILBOX}/inbox/${UNIXDATE}.${QUEUEID}

		sed -i "/\[/r ${JSONTMP}${MAILBOX}" ${JFOLDER}inbox.json
	done

	if [ ${#RECIPIENTS[@]} -gt 0 ]
	then
		sleep 60
		TIMEUP=$(($TIMEUP - 1))
	else
		TIMEUP=0
	fi

done

exit 0
