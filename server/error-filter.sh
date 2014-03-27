#!/bin/bash
#filter error text for LVM backup
#before writing to log and mail
#Written By Manjot Singh
#Version: 1.0
#Last Updated: 2012-09-25

	#get pipe (should come from script with 2>&1)
	LOG=""
	COUNTER=0
	while read LINE; do
		if [ $COUNTER -eq 0 ] && [[ "$LINE" == "" ]]; then exit; fi
		#exceptions
		if	[[ "$LINE"  != *"not mounted"* ]] && [[ "$LINE"  != *"leaked on lvcreate"* ]] &&
			[[ "$LINE"  != *"One or more specified logical volume(s) not found"* ]]; then
			LOG=`echo -e "$LOG\n$LINE"`
		fi
		let COUNTER=COUNTER+1
	done
	
echo "$LOG" | /var/backup/script/logandmail.sh "$1" "$2" "$3"
