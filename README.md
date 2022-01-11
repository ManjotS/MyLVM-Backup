MyLVM-Backup
============

MySQL LVM Backup and Restore
----------------------------

Note: The below methods only apply when using LVM snapshot backups. MySQL masters are configured to use LVM backups and slaves can use mysqldump with local crons. This can be checked in the configuration in /var/backup/script/mysql-backup.conf.

Setup
-----

LVM snapshot is an exact copy of an LVM partition that has all the data from the LVM volume from the time the snapshot was created. The advantages of this is that we get an instant hot backup with minimal stress to the MySQL Server. Normal backup using mysqldump or mysqlhotcopy will create a logical backup, which is usually expensive and CPU intensive.

The idea is like this:

	1. Create a new logical volume in new hard disk
	2. Mount the logical volume into MySQL data and log directory
	3. Create LVM snapshot to the MySQL partition that hold MySQL data and log
	4. Mount the LVM snapshot into the server
	5. Create MySQL backup from that snapshot
	6. Backup MySQL partition: /mysql_snap

Steps to setup:

1. We will use another hard disk to mount **/data** via logical volume. Lets create the partition first:

    ```
    $ fdisk /dev/sdb`
    ```
Sequence pressed on keyboard: n > p > 1 > Enter > Enter > w

2. You should see disk partition has been created as **/dev/sdb1** as below:

   ```
	$ fdisk -l /dev/sdb
	Disk /dev/sdb: 11.8 GB, 11811160064 bytes
	255 heads, 63 sectors/track, 1435 cylinders
	Units = cylinders of 16065 * 512 = 8225280 bytes
	Sector size (logical/physical): 512 bytes / 512 bytes
	I/O size (minimum/optimal): 512 bytes / 512 bytes
	Disk identifier: 0xaa7ca5e3
	Device Boot	Start	End	Blocks		Id	System
	/dev/sdb1	1	1435	11526606	83	Linux
   ```

3. Check the current physical volume, volume group and logical volume details:

	 ```
	$ pvs && vgs && lvs
	
	PV		VG		Fmt	Attr	PSize	PFree
	/dev/sda2	VolGroup00	lvm2 	a--	49.88G	0
	
	VG		#PV	#LV	#SN	Attr	VSize	VFree
	VolGroup00	1	2	0	wz--n-	49.88G	0
	
	LV		VG		Attr	LSize	Origin	Snap%	Move	Log	Copy%	Convert
	LogVol00	VolGroup00	-wi-ao	44.97G
	LogVol01	VolGroup00	-wi-ao	4.91G
	 ```
You can see that this server has a volume group called VolGroup under **/dev/sda2**. Inside this volume group we have another 2 logical volume for root and swap (smaller one).

4. What we are going to do now is to use **/dev/sdb1** (our new hard disk) to extend VolGroup00 and create another logical volume for mysql called **lv_mysql**:

	```
	$ pvcreate /dev/sdb1
	$ vgextend VolGroup00 /dev/sdb1
	```
Now volume VolGroup00 should be extended. You can check **VFree** value by using this command:
	`$ vgs`

5. We will use 50G for MySQL and another 50G will be dedicated to the snapshot volume. Now lets create the mysql logical volume called **lv_mysql**:
`$ lvcreate -L 50G -n lv_mysql VolGroup00`

6. When you run following command, you should see **lv_mysql** has been created under **VolGroup00** volume:

	```
	$ lvs
	LV		VG		Attr	LSize	Origin	Snap% Move Log Copy% Convert
	lv_mysql	VolGroup00	wi-a	50.00g
	```

7. Logical volume created. Lets format it with ext4 filesystem before we can mount them to **/data** directory:

	```
	#if not installed run
	$ yum install -y e4fsprogs
	$ mkfs.ext4 /dev/mapper/VolGroup00-lv_mysql
	$ mkdir /data
	```

8. Add the following line into **/etc/fstab** and mount the partition:
	`/dev/mapper/VolGroup00-lv_mysql /data ext4 defaults 0 0`
Mount the logical volume:
	`$ mount -a`

9. Stop the MySQL service and copy over the data to newly mounted logical volume. We will using rsync to copy to keep the permissions, ownership and timestamp. Dont forget to change ownership for **/data/mysql** directory as well:

	```
	$ service mysql stop
	$ mkdir /data/mysql
	$ rsync -avzP /var/lib/mysql/ /data/mysql/
	$ chown mysql:mysql /data/mysql
	```

10. Change following value in **/etc/my.cnf** to map the new directory:
	`datadir = /data/mysql`
Start the MySQL server:
	`$ service mysqld start`

11. MySQL should start and mapped to the new directory. We can use LVM snapshot from now onwards since MySQL already inside LVM partition. Now, we can start to create snapshot and I will dedicate 50 GB of space for this purpose:
	`$ lvcreate -L 50G --snapshot -n mysql_backup /dev/VolGroup00/lv_mysql`

12. Create snapshot is very fast. Once done, we can check the snapshot status as below:

	```
	$ lvs | grep mysql_backup
	mysql_backup VolGroup00 swi-a- 50.00g lv_mysql 31.32
	```

13. Now lets mount the snapshot partition so we can see the backup data:

	```
	$ mkdir /data_snap
	$ mount /dev/mapper/VolGroup00-mysql_backup /data_snap
	```

14. Create the following directories on the client and server:
	1. **/var/backup/scripts**
	2. **/var/log/mysql**

15. Create **/backup** (ideally a mounted large drive) on the backup pull server.

16. Upload the client scripts to all machines, but only the server should ALSO have the server scripts (overwriting any client scripts).

17. Update conf files with values applicable to your environment.

18. Create ssh keys so that the server can log in with root priveleges without passwords to the clients.
Instructions: [http://www.thegeekstuff.com/2008/11/3-steps-to-perform-ssh-login-without-password-using-ssh-keygen-ssh-copy-id/]http://www.thegeekstuff.com/2008/11/3-steps-to-perform-ssh-login-without-password-using-ssh-keygen-ssh-copy-id/

19. Test **/var/backup/script/mysql-backup** on each client manually to ensure snapshots are created successfully with the script.

Production Server Bin Log rSync
-------------------------------

On Production servers we want to sync bin logs as well.

1. While **/data** is mounted, `mkdir /data/binlog`

2. Add a new 75GB or so drive to the virtual machine.
`mkfs.ext4 /dev/sdc1`

3. Stop the mysqld service

4. Edit **/etc/fstab** to include:

	`/dev/sdc1	/data/binlog	ext4	defaults	0	0`

5. `mount -a`

6. Move any existing bin logs and index files to **/data/binlog** from **/var/log/mysql**
	```
	mv /var/log/mysql/*.index /data/binlog/
	
	mv /var/log/mysql/mysql-* /data/binlog/
	```

7. Change permissions:
	`chown mysql:mysql /data/binlog/`

8. Edit index and control files. You can find things that need to be changed by using grep.

	```
	cd /data/binlog
	grep /var/log *
	```

9. Start the mysql service.

10. On the mysql-backup server edit /var/backup/script/rsync-binlogs.sh by copying an existing line and changing it to the server just configured.

Backup Method
-------------

MySQL Backups are done using the MySQL Backup shell script in /var/backup/script on the client and the getLVMbackups.sh included in the package on the mysql-backup server.

runScheduledbackups.sh on the backup server manages the backup and logging. It can run from every half hour to every day and cycle through the servers in servers.conf. getLVMbackups logs into each of these servers, runs the mysql-backup.sh script on the server to create a snapshot and then rsyncs the snapshot to the backup server. It then runs delete-snapshot.sh to delete the snapshot on the client.

Once this is complete, the backup server compresses all of the backups, archives and deletes old backups and pushes the updates to TSM via the dsmcad service. This can be changed or removed depending on your backup strategy.

**Server TSM settings:**
	```
	nano /opt/tivoli/tsm/client/ba/bin/inclexcl
	
	exclude /dev/*
	
	include /backup/*.tar.gz RDBMS
	
	exclude.dir /backup/*
	```

**Crontab:**
	```
	16 */4 * * * /var/backup/script/runScheduledBackup.sh > /dev/null
	5,35 * * * * /var/backup/script/rsync-binlogs.sh >> /var/log/mysql/backup.log
	```

rsync-binlogs.sh is configured to rsync binary logs every half hour from production servers for point in time recovery. This can be configured by editing the script.

Binary logs are backed up to /backup/SERVERNAME/binlog with the rsync script.

Restore Options
---------------

The recommended restore method is to log into the server mysql-backup and restore the latest backup there by using it as a vanilla box. **Note: These commands will wipe out the database on mysql-backup. Be sure you are logged into the correct server.**

	```
	service mysqld stop
	
	rm -rF /var/lib/mysql/*
	
	tar -C /tmp -xzvf /backup/SERVERNAME.current.TIME.tar.gz
	
	mv /tmp/SERVERNAME/mysql/* /var/lib/mysql/
	
	service mysqld start
	```

You now have an online copy of the database. At this point you can replay binary logs to do point in time or do a mysqldump of the data you need
to recover and scp it to the server in question to restore.

`mysqldump --triggers --routines -u root -p --databases x y z > x_y_z_DATE.sql`

**or you can do**

	```
	mysqldump --triggers --routines -u root -p --all-databases > full_dump.sql
	
	scp myfile.sql root@SERVERNAME:
	
	ssh root@SERVERNAME
	
	mysql -p`
	
	`MYSQL> #may need to USE DATABASE;
	
	MYSQL> source myfile.sql
	
	MYSQL> exit
	```

Replaying Binary Logs
---------------------
Backed up binary logs on the backup server are located in `/backup/SERVERNAME/binlogs`


References:
-----------
http://blog.secaserver.com/2012/05/mysql-live-backup-lvm-snapshots/

