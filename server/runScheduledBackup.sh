#!/bin/bash
#Script for crons that run MySQL Backup Script
#Written By Manjot Singh
#Version: 1.6
#Last Updated: 2012-06-22

#needs trailing slash
LOG_LOC='/var/log/mysql/'

#these should be relative to the LOG_LOC
ERROR_LOG='backup.err'
BACKUP_LOG='backup.log'

#only one address supported!
NOTIFY_EMAIL='test@test.com'

#scripts
BACKUP_SCRIPT=/var/backup/script/getLVMBackup.sh
LANDM=/var/backup/script/logandmail.sh
#error filter
LANDME=/var/backup/script/error-filter.sh

#LANDM=tee

#if its the first of the month, archive last month's log
if [ `date +%d` -eq 1 ]; then
	lastmonth=`date --date="last month" +%Y-%m_`
	mv ${LOG_LOC}${ERROR_LOG} ${LOG_LOC}${lastmonth}${ERROR_LOG}
	mv ${LOG_LOC}${BACKUP_LOG} ${LOG_LOC}${lastmonth}${BACKUP_LOG}
fi

(/var/backup/script/timeout3.sh -d 9000 ${BACKUP_SCRIPT} 2>&1 1>&3 | ${LANDME} ${LOG_LOC}${ERROR_LOG} ${NOTIFY_EMAIL} "ERROR in `hostname -s` Backup") 3>&1 1>&2 | ${LANDM} ${LOG_LOC}${BACKUP_LOG} ${NOTIFY_EMAIL} "`hostname -s` Backup Completed"
