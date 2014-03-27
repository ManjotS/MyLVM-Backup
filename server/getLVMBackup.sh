#!/bin/bash
#Script for crons that run MySQL Backup Script on remote server using LVM
#Written By Manjot Singh
#Version: 1.6
#Last Updated: 2012-09-04

#change dir to script location
cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#pull in settings
source mysql-backup.conf

curhour=`date +%H`

#loop through servers.txt to get snapshots
while IFS='' read -r LINE || [ -n "$LINE" ]; do

if [ -n "$LINE" ]; then

	#backup file name
	BUfile="${BUdir}/${LINE}.current.${curhour}.00.tar.gz"

	#check if file exists, if so move it to archive with yesterday's date.
	echo "Checking if ${LINE} backup exists from yesterday..."
	if [ -e "$BUfile" ]
		then
			echo "Moving archive file..."
			BUfileDate=$(stat -c %y $BUfile)
			BUfileDate=${BUfileDate%% *}
			BUArchive="${BUdir}/archive/${LINE}.${BUfileDate}.${curhour}.00.tar.gz"
			COUNTER=1
			 while [ -e "$BUArchive" ]; do
				 BUArchive="${BUdir}/archive/${LINE}.${BUfileDate}.${curhour}.00_${COUNTER}.tar.gz"
				 let COUNTER=COUNTER+1 
			 done
		
			mv "$BUfile" "$BUArchive"
	fi

	echo "Logging into ${LINE}"
    ssh -n root@$LINE "/var/backup/script/mysql-backup.sh"
	
	echo "Checking local backup directory..."
	BACKDIR="${BUdir}/${LINE}"
	mkdir $BACKDIR 2>/dev/null
	
	echo "Rsyncing to ${BACKDIR}..."
	rsync -qaH --delete-after --rsh=/usr/bin/ssh $LINE:/data_snap/ $BACKDIR
	
    ssh -n root@$LINE "/var/backup/script/delete-snapshot.sh"
	
	echo "Done with backup of ${LINE}"
	
	echo
	echo
fi	
done < /var/backup/script/servers.conf

echo "Compressing backups..."

#loop through servers.txt to compress
while IFS='' read -r LINE || [ -n "$LINE" ]; do

if [ -n "$LINE" ]; then

	#backup file name
	BUfile="${BUdir}/${LINE}.current.${curhour}.00.tar.gz"
	
	echo "Compressing ${LINE}..."
	cd "${BUdir}"
	tar czf "${BUfile}" "${LINE}"
	cd - > /dev/null
	
	echo
fi	
done < /var/backup/script/servers.conf

echo "Compression Complete!"

#delete old files
echo "Deleting old archive files..."
find $BUdir/archive/*.tar.gz -mtime +4 -exec rm {} \;
find $BUdir/*.tar.gz -mtime +3 -exec rm {} \;

echo "Backup Files:"
ls -lh $BUdir/*.tar.gz
echo
echo "Backup Files Archive:"
ls -lh $BUdir/archive
echo
echo "Drive Space:"
df -h
echo
echo "Backing up to TSM:"
dsmc i "${BUdir}/*.tar.gz" -subdir=yes
echo

echo "getLVMBackup completed"
date