#Use this script to copy binlogs somewhere

rsync -qaH --delete-after --rsh=/usr/bin/ssh mysqlprod01:/data/binlog /backup/mysqlprod01/
