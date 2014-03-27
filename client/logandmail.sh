#!/bin/bash
#Write to log and mail
#Written By Manjot Singh
#Version: 1.1
#Last Updated: 2012-06-22

#check for info
if [ -z "$2" ]; then
	echo "Usage ./logandmail.sh log-file-path email-address [subject]"
	echo
	#do work
	else
	#get pipe (should come from script with 2>&1)
	LOG=""
	COUNTER=0
	while read LINE; do
		if [ $COUNTER -eq 0 ] && [[ "$LINE" == "" ]]; then exit; fi
		echo "$LINE" >> $1
		LOG="$LOG\n$LINE"
		let COUNTER=COUNTER+1
	done

	if [[ "$LOG" == "" ]]; then exit; fi	

	#check if subject is set, and output
	if [ -n "$3" ]; then
		echo -e $LOG | mail -s "$3" $2
	else
		echo -e $LOG | mail $2
	fi
fi
