#!/bin/bash
#MySQL Backup delete snapshot
#Written By Manjot Singh
#Version: 1.6
#Last Updated: 2012-09-04

#settings
ISMASTER=""
ENGINE="mysqldump"

#change dir to script location
cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#pull in settings
source mysql-backup.conf


################################################
#script starts here

echo "Unmounting snapshot if mounted..."
umount /$SNAP_MOUNTDIR
echo "Deleting snapshot if any..."
lvremove -f /dev/$VOLGROUP/$SNAPNAME
echo
