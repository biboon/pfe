#!/bin/bash
# Simple json parser script
# Supposed to be called by the filter.sh script
# Current parameters $@ = $queue_id $size $sender $recipient

INTMP=/tmp/in.$$
JSONTMP=/tmp/newmail.json.$$
USERDATA=/home/vmail/userdata/
MAILBASE=/home/vmail/
LOGFILE=/var/log/intimail/json_parser.log
MINSIZE=4
RETRIES=8 # Number of retries
SLEEPTIME=1 # Initial sleep time in seconds

# Exit codes from <sysexits.h>
EX_TEMPFAIL=75
EX_UNAVAILABLE=69
EX_CANTCREAT=73

echo $$ >> /tmp/json_parser.pid
echo `date +%F%t%T%t` Starting json_parser/pid:$$ using arguments: $@ >> $LOGFILE

# Clean up when done or aborting
trap "rm -f /tmp/*.$$.* /tmp/*.$$ /tmp/json_parser.pid; echo `date +%F%t%T%t` json_parser exited with code $? >> $LOGFILE; exit $?" 0 1 2 3 15

# Parse arguments
QUEUEID=$1
SIZE=$2
FROM=$3
RECIPIENTS=("${@:4}")
RECINB=${#RECIPIENTS[@]}

cat > $INTMP || {
	echo Cannot save mail to $INTMP >> $LOGFILE; exit $EX_TEMPFAIL; }


# Let's parse the data
DATE=`date +%F\ %T`
UNIXDATE=`date -d "$DATE" +%s`
SUBJECT=`grep Subject: $INTMP | sed 's/Subject: \(.*\)/\1/'` || unset SUBJECT
if [ -z "$SUBJECT" ]
then
	SUBJECT="(No Subject)"
fi


# Writing some tmp files
echo '{' >> $JSONTMP || {
	echo Cannot write temp file $JSONTMP >> $LOGFILE; exit $EX_CANTCREAT; }
echo -e "\t\"from\": \"$FROM\"," >> $JSONTMP
echo -e "\t\"subject\": \"$SUBJECT\"," >> $JSONTMP
echo -e "\t\"timestamp\": \"$DATE\"," >> $JSONTMP
echo -e "\t\"unixtimestamp\": \"$UNIXDATE\"," >> $JSONTMP
echo -e "\t\"queueid\": \"$QUEUEID\"," >> $JSONTMP
echo -e "\t\"size\": \"$SIZE\"," >> $JSONTMP
echo -e "\t\"status\": \"0\"," >> $JSONTMP
echo -e "\t\"pj\": \"0\"," >> $JSONTMP
#echo Written temp file $JSONTMP >> $LOGFILE

# Create the directory if it doesn't exist
if [ ! -d $USERDATA ]
then
	mkdir $USERDATA
	chmod g=rwx $USERDATA
	echo Created directory $USERDATA >> $LOGFILE
fi

# Start processing
while [ $RETRIES -gt 0 ]
do

	for (( index=0; $RECINB-$index; index++ ))
	do
		unset MAILBOX
		unset DOMAIN
		unset JFOLDER
		unset ID

		param=${RECIPIENTS[$index]}
		echo Doing recipient \#$index of $RECINB $param >> $LOGFILE
		
		# Get the folder to write in
		MAILBOX=`echo $param | cut -f1 -d@`
		DOMAIN=`echo $param | cut -f2 -d@`
		if [ -z "$MAILBOX" -o -z "$DOMAIN" ]
		then
			echo Error in recipients list $MAILBOX $DOMAIN >> $LOGFILE; exit $EX_TEMPFAIL;
		fi
	
		# Create the folders if needed and assign rights
		if [ ! -d ${USERDATA}${DOMAIN} ]
		then
			mkdir ${USERDATA}${DOMAIN}
			chmod g=rwx ${USERDATA}${DOMAIN}
			echo Created directory ${USERDATA}${DOMAIN} >> $LOGFILE
		fi
		JFOLDER=${USERDATA}${DOMAIN}/${MAILBOX}/json/
		if [ ! -d $JFOLDER ]
		then
			mkdir -p $JFOLDER
			chmod -R g=rwx ${USERDATA}${DOMAIN}/${MAILBOX}
			echo Created directory $JFOLDER >> $LOGFILE
		fi
	
		# Create inbox.json if it doesn't exist
		if [ ! -f ${JFOLDER}inbox.json ]
		then
			echo '[' >> ${JFOLDER}inbox.json
			echo ']' >> ${JFOLDER}inbox.json
			chmod g=rwx ${JFOLDER}inbox.json
			echo Created inbox.json for $param >> $LOGFILE
		fi

		# GET THE ID MUDAFUGA
		ID=`grep \"id\" ${JFOLDER}inbox.json | head -n 1 | sed 's/.*\"\([0-9]*\)\".*/\1/g'`
		if [ ! -z "$ID" ]
		then
			ID=$(($ID + 1))
		else
			ID=0
		fi

		# Try to get the filepath
		FOLDERMAILBOX=${MAILBASE}${DOMAIN}/${MAILBOX}/new/
		FILELIST=`grep -rli $QUEUEID $FOLDERMAILBOX` || unset FILELIST
		if [ -z "$FILELIST" -o `echo "$FILELIST" | wc -l` -ne 1 ]
		then
#			echo Could not find mail with id $QUEUEID in $FOLDERMAILBOX >> $LOGFILE
			continue
		else
			FILEPATH=${FILELIST#$FOLDERMAILBOX}
#			echo Found mail with id $QUEUEID in $FOLDERMAILBOX: $FILEPATH >> $LOGFILE
		fi

		# Let's copy and finish to write the info before inserting into json
		cp $JSONTMP ${JSONTMP}.${MAILBOX}
		echo -e "\t\"id\": \"$ID\"," >> ${JSONTMP}.${MAILBOX}
		echo -e "\t\"to\": \"$param\"" >> ${JSONTMP}.${MAILBOX}

		if [ $ID -ne 0 ]
		then
			echo "}," >> ${JSONTMP}.${MAILBOX}
		else
			echo '}' >> ${JSONTMP}.${MAILBOX}
		fi
		if [ ! -d ${USERDATA}${DOMAIN}/${MAILBOX}/inbox/ ]
		then
			mkdir ${USERDATA}${DOMAIN}/${MAILBOX}/inbox/
			chmod g=rwx ${USERDATA}${DOMAIN}/${MAILBOX}/inbox/
			echo Created directory ${USERDATA}${DOMAIN}/${MAILBOX}/inbox/ >> $LOGFILE
		fi

		# Move the files and finish
		mv $FILELIST ${USERDATA}${DOMAIN}/${MAILBOX}/inbox/${UNIXDATE}.${QUEUEID}
		chmod g=rwx ${USERDATA}${DOMAIN}/${MAILBOX}/inbox/${UNIXDATE}.${QUEUEID}

		RECIPIENTS=(${RECIPIENTS[@]:0:$index} ${RECIPIENTS[@]:$(($index + 1))})
		((RECINB--))
		((index--))
		
		# Set the new value in quota.json
		if [ -f ${JFOLDER}quota.json ]
		then
			SIZE=$(($SIZE + `cat ${JFOLDER}quota.json`))
		else
			touch ${JFOLDER}quota.json
			chmod g=rwx ${JFOLDER}quota.json
		fi
		echo $SIZE > ${JFOLDER}quota.json
		
		# Insert new json info in main file
		sed -i "/\[/r ${JSONTMP}.${MAILBOX}" ${JFOLDER}inbox.json
	done

	if [ $RECINB -gt 0 ]
	then
		sleep $SLEEPTIME
		SLEEPTIME=$(($SLEEPTIME*2))
		((RETRIES--))
		if [ $RETRIES -eq 0 ]
		then
			echo Could not process mail $QUEUEID >> $LOGFILE
		fi
	else
		RETRIES=0
	fi

done

exit 0
