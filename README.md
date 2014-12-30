zbackup-tar
===========

Incremental tar backups with the amazing zbackup.

## Why Use It?
zbackup dedupicates tars of very large directory trees so that backing up 100GB of files repeatedly takes very little additional disk spaces.
````
tar -cv /big/files/ | zbackup backup /var/backups/zbackup/backups/bigfiles12.tar
tar -cv /big/files/ | zbackup backup /var/backups/zbackup/backups/bigfiles13.tar
````
Assuming the /big/files directory hasn't changed much, the marginal size used by bigfiles13.tar is very small.

**However, the downside is that the entire /big/files/ directory has to be read and tarred** before zbackup then detects the duplicates and throws the bytes away.  For 100GB, this is a *lot* of IO, and if you multiply that across a set of virtual servers it can saturate the disk IO on a physical server.

zbackup-tar is a *very relaxed* incremental tarring tool.  Very relaxed means that the cost of tarring a file we don't need is very low (since it will be deduplicated) so we can tar files we don't strictly need, so long as we never miss tarring a file we do need.

## How to backup
Creating a backup is easy, except you must provide the previous backup as well.  A simple find command should be able to do this.
````
# Init zbackup store
zbackup init --non-encrypted /var/backups/zbackup/

# Initial backup passes empty string for the previous backup
zbackup-tar create --previousBackup "" --newBackup /var/backups/zbackup/backups/bigfiles1.tar /big/files/

# Subsequent backups
zbackup-tar create --previousBackup /var/backups/zbackup/backups/bigfiles1.tar --newBackup /var/backups/zbackup/backups/bigfiles2.tar /big/files/
zbackup-tar create --previousBackup /var/backups/zbackup/backups/bigfiles2.tar --newBackup /var/backups/zbackup/backups/bigfiles3.tar /big/files/
````

You can also exclude files:
````
# Exclude log files
zbackup-tar create --previousBackup /var/backups/zbackup/backups/bigfiles3.tar --newBackup /var/backups/zbackup/backups/bigfiles4.tar --exclude "*.log" /big/files/

# Exclude tmp dir
zbackup-tar create --previousBackup /var/backups/zbackup/backups/bigfiles3.tar --newBackup /var/backups/zbackup/backups/bigfiles4.tar --exclude "tmp/" /big/files/

````

If you get the previous backup wrong *don't worry*, it just means you back up more files.

## How to restore
Restoring files follows a similar syntax.

````
cd /place/to/restore
zbackup-tar restore --backup /var/backups/zbackup/backups/bigfiles4.tar
````

You can restore a specific folder or file:
````
cd /place/to/restore
zbackup-tar restore --backup /var/backups/zbackup/backups/bigfiles4.tar folder1/
````

## Advanced considerations
### Summary
It is useful to freshen our files at regular intervals (because zbackup deduplicates, this has no storage cost).  For example, if we want to ensure that our files are no older than 48h +/- 2h, we do the following:

````
# Freshen files between 46 - 40h
zbackup-tar create --previousBackup /var/backups/zbackup/backups/bigfiles4.tar --newBackup /var/backups/zbackup/backups/bigfiles5.tar --exclude "*.log" --maxAge 48 --maxAgeJitter 2 /big/files/

````

### Why
Large directory trees with 100k+ files that are slowly changing will eventually find their contents spread across 1000s of tar files backed up months or even years ago.  This will slow down the restore because many tar files are being opened and read and much of the contents has been superseded.

For this reason, the option --maxAge exists.  This is an optional parameter that inidcates that any file older than maxAge hours should be refreshed in the tar.  Thanks to the magic of zbackup, it will be deduplicated anyway.

For example, if I backup every hour and set --maxAge 48 then I can be sure that all files will exist within the last 48 tar files (two days).  This should be efficient to restore.

This creates its own problem.  As an example, suppose we touch all the files in the directory being backed up.  All the files will be backed up, which is unavoidable.  However, 48 hours later all the files will be refreshed.  Then 48 hours later again, and so on.  The result is that 47 backups do almost nothing and then the each 48th backup backs up the entire directory tree, which is the exact IO load problem we tried to avoid in the first place.

The solution is --maxAgeJitter.  This flag goes in tandem with maxAge and it deterministically varies the maxAge for each file based on the filename.  So for example with a jitter of 2 hours the maxAge might vary from 46 - 50 hours.  Each file will have it's own unique maxAge based on a hash of the filename.  The result is that large groups of changed files will gradually drift apart and be refreshed in different intervals and so each backup will refresh 1 / 48th of all the files (in the example of maxAge 48 with hourly backups)


## How it works
Each backup contains two files, the tar file and the manifest.  These files are stored by zbackup in the backups folder.

The manifest has the same name as the tar file with .manifest on the end.  so for example we might have:
/var/backups/zbackup/backups/bigfiles12.tar
/var/backups/zbackup/backups/bigfiles12.tar.manifest

Each manifest contains the list of all files.  For each file we record the last modified date, the last backup date, and the tar file containing the file.  The tar file contains just the changed files.

The example manifest below has two files, contained in two different tar files.  The tar files are relative to the zbackup root.
````
<?xml version="1.0" ?>
<info>
  <bDir>testdata/</bDir>
  <fDesc>
    <name>document.odt</name>
    <size>31365</size>
    <modOn>2014-12-24T12:23:34</modOn>
    <backupOn>2014-12-30T11:25:02</backupOn>
    <path>backups/backup16.tar</path>
  </fDesc>
  <fDesc>
    <name>folder1/subfolder1/1.jpg</name>
    <size>373835</size>
    <modOn>2014-12-24T12:23:34</modOn>
    <backupOn>2014-12-30T11:22:54</backupOn>
    <path>backups/backup11.tar</path>
  </fDesc>
````

## Running the unit test
The file test/test.sh runs a set of unit tests to ensure that the backup system works properly.  It is also a good example of how to use the tool.

Assuming that the project has been cloned to $GITROOT
````
export PATH=$PATH:$GITROOT
cd $GITROOT/tests
test.sh $GITROOT/tests/testdata
````

The app will create a zbackup store in /tmp/zbacup-tar/zbackup

