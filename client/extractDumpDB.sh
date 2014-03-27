#!/bin/bash
#Write to log and mail
#Written By Manjot Singh
#Version: 1.4
#Last Updated: 2012-05-15

#check for info
if [ -z "$2" ]; then
	echo "Usage ./extractDumpDB.sh /path/to/bak.mysql.date.sql databasename > mydb.sql"
echo
#do work
else

	line=`grep -m 1 -n "Current Database: .$2" $1 | cut -d ":" -f 1`
	next=`sed 1,${line}d $1 | grep -m 1 -n "Current Database" | cut -d ":" -f 1`
	end=$(($line + $next - 1))
	sed -n ${line},${end}p $1

	echo
	echo "-- bring in views"
	echo

	#views are defined later in a dump
	line=$((`sed 1,${end}d $1 | grep -m 1 -n "Current Database: .$2" | cut -d ":" -f 1` + $end))
	next=`sed 1,${line}d $1 | grep -m 1 -n "Current Database" | cut -d ":" -f 1`
	end=$(($line + $next - 1))
	sed -n ${line},${end}p $1

fi