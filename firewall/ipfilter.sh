#!/bin/bash
# more info on iptables on http://www.thegeekstuff.com/2011/06/iptables-rules-examples/

IPT=/sbin/iptables

localnetwork=192.168.1.0/24


# Usage function
usage() { echo "Usage: $0 [-b blacklist] [-w whitelist]"; exit 1; }

unset WHITELIST
unset BLACKLIST

# Interdire toute connexion entrante et sortante
echo 'Dropping all traffic'
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
#$IPT -P OUTPUT DROP


# Ne pas casser les connexions etablies
$IPT -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
#$IPT -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT


# Accept everything from the 192.168.1.x network
#echo 'Accept traffic coming from the local network' $localnetwork
#$IPT -A INPUT -i eth0 -s $localnetwork -j ACCEPT


# Autoriser le loopback
echo 'Allowing loopback interface...'
$IPT -A INPUT -i lo -j ACCEPT


while getopts ":b:w:" options
do
	case $options in
		# Accept traffic from ip specified in whitelist
		w)
			BLACKLIST=$OPTARG
			echo 'Accepting traffic from ip specified in the whitelist'
			while read line
			do
			        [ -z "$line" ] && continue
        			if [ ! ${line:0:1} == "#" ]
        			then
                			echo "Allowing ip $line..."
					$IPT -A INPUT -i eth0 -s $line -j ACCEPT
				fi
			done < $BLACKLIST
			;;

		# Block traffic from ip specified in blacklist
		b)
			WHITELIST=$OPTARG
			echo 'Blocking traffic from ip specified in the blacklist'
			while read line
			do
				[ -z "$line" ] && continue
				if [ ! ${line:0:1} == "#" ]
				then
					echo "Blocking ip $line..."
					$IPT -A INPUT -i eth0 -s $line -j DROP
				fi
				done < $WHITELIST
				;;

		*)
			echo "unrecognized option -$OPTARG"
			usage
			;;
	esac
done

if [ -z $WHITELIST ] || [ -z $BLACKLIST ]
then
	usage
fi
