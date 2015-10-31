#!/bin/bash


TMPFOLDER=/tmp/
TMPFILEEXT=.blk.tmp
IPT=/sbin/iptables

WHITELIST=/etc/iptables/whitelist.txt
BLACKLIST=/etc/iptables/blacklist.txt


# Get SASL LOGIN authentication failed lines from mail.log
cat /var/log/mail.log | grep SASL\ LOGIN\ authentication\ failed >> ${TMPFOLDER}1${TMPFILEEXT}

# Get ips only
cat ${TMPFOLDER}1${TMPFILEEXT} | sed -ne 's/.*[^0-9]\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)[^0-9].*/\1/p' >> ${TMPFOLDER}saslips${TMPFILEEXT}

# Sort and remove dubs
cat ${TMPFOLDER}saslips${TMPFILEEXT} | sort | uniq >> ${TMPFOLDER}3${TMPFILEEXT}

# Remove ips of the whitelist
cat ${TMPFOLDER}3${TMPFILEEXT} | grep -vwf $WHITELIST >> ${TMPFOLDER}4${TMPFILEEXT}

# Remove ips already in the blacklist
cat ${TMPFOLDER}4${TMPFILEEXT} | grep -vwf $BLACKLIST >> ${TMPFOLDER}5${TMPFILEEXT}

# Append to blacklist if new ips and block
if [ -s ${TMPFOLDER}5${TMPFILEEXT} ]
then
	unset CURDATE
	CURDATE=`date +%D\ %T`
	echo '' >> $BLACKLIST
	echo "#$CURDATE" >> $BLACKLIST
	cat ${TMPFOLDER}5${TMPFILEEXT} >> $BLACKLIST

	while read line
	do
		[ -z "$line" ] && continue
		if [ ! ${line:0:1} == "#" ]
		then
			echo "Blocking new ip $line..."
			$IPT -A INPUT -i eth0 -s $line -j DROP
		fi
	done < ${TMPFOLDER}5${TMPFILEEXT}
else
	echo 'Nothing new to block'
fi

# Save modifications
service iptablesd save

# Remove temp files
rm -f ${TMPFOLDER}*${TMPFILEEXT}
