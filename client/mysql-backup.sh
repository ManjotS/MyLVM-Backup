#!/bin/bash
#MySQL Backup Script
#Written By Manjot Singh
#Version: 1.6
#Last Updated: 2013-05-29

#default settings
ISMASTER=""
ENGINE="mysqldump"
COMPRESSDUMP=1

#standard functions
err() { echo "$@" 1>&2; }
die() { err "Fatal Error: $@"; exit 1; }
include () { [[ -f "$1" ]] && source "$1"; }
require () {
    if [[ -f "$1" ]]; then source "$1";
	else die "$1 not found."; fi
}

#change dir to script location
cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#pull in settings
require mysql-backup.conf


################################################
#script starts here

# is it a compressed dump?
if [ $COMPRESSDUMP -eq 1 ]; then
	DUMPEXT="sql.gz"
else
	DUMPEXT="sql"
fi

#backup file name
curhour=`date +%H`
BUfileBase="${BUdir}/bak.mysql.current.${curhour}.00"
FullBUfile="${BUfileBase}.${DUMPEXT}"
BUfile="${BUfileBase}.sql"

echo "Starting MySQL Backup Script 1.6 on `hostname -s`..."
date

echo "Using engine ${ENGINE}"

if [ $DISABLE_ALERTS -eq 1 ]; then
	echo "Disabling Alerts..."
	./timeout3.sh -d 10 curl $MONYOG_DIS
	echo
fi

if [ "$ENGINE" = "lvm" ]; then
	echo "Unmounting previous snapshot if mounted"
	umount /$SNAP_MOUNTDIR
	echo "Deleting previous snapshots if any..."
	lvremove -f /dev/$VOLGROUP/$SNAPNAME
	
	mysql -h $DBhost -u $DBuser -p$DBpassword <<EOD
	system echo "Locking tables and flushing logs..."
	FLUSH TABLES WITH READ LOCK;
	FLUSH LOGS;
	system echo "Chevron 7 Locked!!"
	system echo "Retrieving current log position:"
	SHOW MASTER STATUS;
	system sleep 5
	system echo "Creating snapshot..."
	system lvcreate -L $SNAPSIZE --snapshot -n $SNAPNAME "/dev/${VOLGROUP}/${VOLUME}"
	system echo "Unlocking tables..."
	UNLOCK TABLES;
EOD
	echo "Mounting snapshot..."
	mount -r /dev/$VOLGROUP/$SNAPNAME /$SNAP_MOUNTDIR
else
	#non lvm backup
	#check if file exists, if so move it to archive with yesterday's date.
	echo "Checking if backup exists from yesterday..."
	if [ -e "$FullBUfile" ]
		then
			echo "Moving archive file..."
			BUfileDate=$(stat -c %y $FullBUfile)
			BUfileDate=${BUfileDate%% *}
			BUArchive="${BUdir}/archive/bak.mysql.${BUfileDate}.${curhour}.00.${DUMPEXT}"
			COUNTER=1
			while [ -e "$BUArchive" ]; do
				 BUArchive="${BUdir}/archive/bak.mysql.${BUfileDate}.${curhour}.00_${COUNTER}.${DUMPEXT}"
				 let COUNTER=COUNTER+1 
			 done
		
			mv "$FullBUfile" "$BUArchive"
	fi

	#do the dump, add -v for verbose
	echo "Dumping all databases and flushing logs..."
	mysqldump \
	--host=$DBhost \
	--user=$DBuser \
	--password=$DBpassword \
	--quick \
	--triggers \
	--routines \
	--add-drop-table \
	--complete-insert \
	--single-transaction \
	--flush-logs \
	--all-databases \
	--max_allowed_packet=512M \
	--result-file=$BUfile \
	$ISMASTER

	#get grants
	echo "Backing up grants..."
	echo "-- " >> $BUfile
	echo "-- Backup Grants" >> $BUfile
	echo "-- " >> $BUfile
	mysql -B -N -u $DBuser -p$DBpassword -e "SELECT DISTINCT CONCAT('SHOW GRANTS FOR ''', user, '''@''', host, ''';') AS query FROM mysql.user" | \
	mysql -u $DBuser -p$DBpassword | \
	sed 's/\(GRANT .*\)/\1;/;s/^\(Grants for .*\)/## \1 ##/;/##/{x;p;x;}' >> $BUfile
	
	#gzip it
	if [ $COMPRESSDUMP -eq 1 ]; then
		echo "Compressing Backup..."
		gzip $BUfile
	fi
		
	#chmod
	echo "Changing Permissions..."
	chmod 600 $FullBUfile

	#delete old files
	echo "Deleting old archive files..."
	find $BUdir/archive/bak.mysql.* -mtime +3 -exec rm {} \;
	find $BUdir/bak.mysql.* -mtime +6 -exec rm {} \;

	#done
	echo "Completed Dump and Archive"
	date
	echo
	echo "Backup Files:"
	ls -lh $BUdir/
	echo
	echo "Backup Files Archive:"
	ls -lh $BUdir/archive
	echo
	echo "Drive Space:"
	df -h
	echo
	echo "Backing up to TSM:"
#	dsmc i "${BUdir}/*" -subdir=yes
	echo
fi

if [ $DISABLE_ALERTS -eq 1 ]; then
	echo "Enabling Alerts..."
	./timeout3.sh -d 10 curl $MONYOG_EN
	echo
fi

echo "`hostname -s` backup completed!"
echo
