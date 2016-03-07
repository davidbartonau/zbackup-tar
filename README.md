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

#### Performance Comparison
I have included a couple of examples below to give an idea of the difference.  They illustrate a difference of 10 - 23 times.  Of course, YMMV.

On my laptop, backing up 15G stored across 190k files, where the data is already de-duped in zbackup on an i7 with an SSD
* tar: 3m 2s (limited by disk speed)
* zbackup-tar: 19s (limited by python CPU performance)

On a virtual server backing up 9G stored across 195k files, where the data is already de-duped in zbackup.  The disk and CPU are slower than the laptop.
* tar: 15m 28s (limited by disk speed)
* zbackup-tar: 40s (limited by python CPU performance)


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

## zbackup-tar Parameters
zbackup-tar supports additional parameters as listed below:
- --exclude  Backing up only. Pass in a list of glob patterns of files to exclude from the backup.
- --refreshCycles Backing up only. A number used to ensure files are refreshed in the tar file at least ever N backup cycles.  See Advanced considerations
- --verbosity Backing up & restoring.  A number like 1 or 2 used to make zbackup-tar log more information
- --zbackupArgs Backing up & restoring.  Used to pass additional parameters to zbackup, see Encryption and additional zbackup parameters

## Encryption and additional zbackup parameters
Encrypted zbackup stores are specified using --password-file
````
# Use the encryption key file /root/my.key
zbackup-tar restore --password-file /root/my.key --backup /var/backups/zbackup/backups/bigfiles4.tar folder1/
````

Additional parameters can be passed to zbackup in raw form using --zbackupArgs, with a single argument
````
# Pass a b c as 3 arguments to zbackup
zbackup-tar restore --zbackupArgs "a b c" /root/my.key --backup /var/backups/zbackup/backups/bigfiles4.tar folder1/
````

## Advanced considerations
### Summary
It is useful to freshen our files at regular intervals (because zbackup deduplicates, this has no storage cost).  For example, if we want to ensure that our files are within the last 48 backups, we do the following:

````
# Freshen files within the last 48 backups
zbackup-tar create --previousBackup /var/backups/zbackup/backups/bigfiles4.tar --newBackup /var/backups/zbackup/backups/bigfiles5.tar --exclude "*.log" --refreshCycles 48 /big/files/

````

### Why
Large directory trees with 100k+ files that are slowly changing will eventually find their contents spread across 1000s of tar files backed up months or even years ago.  This will slow down the restore because many tar files are being opened and read and much of the contents has been superseded.

For this reason, the option --maxAge exists.  This is an optional parameter that inidcates that any file older than maxAge hours should be refreshed in the tar.  Thanks to the magic of zbackup, it will be deduplicated anyway.

For example, if I backup every hour and set --refreshCycles 48 then I can be sure that all files will exist within the last two days.  This should be efficient to restore.

There are some special considerations for small files that zbackup cannot deduplicate singly.  zbackup deduplicates blocks and if the file is smaller than a block, this can lead to catastrophically bad behaviour e.g.:
- backup A, B, C on day 1
- backup C, D, E on day 2 
- backup A, C, E on day 3
- backup B, C, A on day 4

In each case, zbackup is **unable to deduplicate** the files because the file bytes are deduplicated as a unit and the full storage cost is paid each time.  This is especially troubling for day 4, when it is the same files as day 1, just in a different order.  For this reason, zbackup-tar will always refresh files together as a cohort based on the hash of the filename.  Additionally, the order the files are tarred is consistent based on alphabetical order.


## How it works
Each backup contains two files, the tar file and the manifest.  These files are stored by zbackup in the backups folder.

The manifest has the same name as the tar file with .manifest on the end.  so for example we might have:
/var/backups/zbackup/backups/bigfiles12.tar
/var/backups/zbackup/backups/bigfiles12.tar.manifest

Each manifest contains the list of all files.  For each file we record the last modified date, the last backup date, and the tar file containing the file.  The tar file contains just the changed files.

### Manifest File Format
The example manifest below has two files, contained in two different tar files.  The tar files are relative to the zbackup root.
````
HEADER,1,573
./Admin/Directors Meetings,4096,1287648212,1456913600,backups/2016-03/02/18_13/david_1iT.tar,1000,1000,0
./Admin/Directors Meetings/20000410Agenda.doc,19456,1101024335,1456816395,backups/2016-03/01/15_13/david_1iT.tar,1000,1000,1
./Admin/Directors Meetings/20000410Appendum.doc,20480,1101024335,1456902794,backups/2016-03/02/15_13/david_1iT.tar,1000,1000,1
````

The first row of the CSV is the header.  It contains the word HEADER, the format version number (currently only 1), and the number of backups in this sequence.  Remembering that every backup in zbackup-tar is based on a previous backup manifest, this tells you how far back to go.

After this, each row is an entry in the tarfile, or a previous tarfile.  The format of each row is:
- File name
- Size in bytes
- Modification time since epoch in seconds [1]
- Last Backup time since epoch in seconds
- Path to the tarfile stored in this zbackup repository, relative to the repository root
- UID of the file owner [1]
- GID of the file group [1]
- 1 if this is a file, 0 if it is a directory

[1] These values are stored to rapidly determine if a file changes between backups, tar is still used to restore the actual values.

## Running the unit test
The file test/test.sh runs a set of unit tests to ensure that the backup system works properly.  It is also a good example of how to use the tool.

Assuming that the project has been cloned to $GITROOT
````
export PATH=$PATH:$GITROOT
cd $GITROOT/tests
test.sh $GITROOT/tests/testdata
````

The app will create a zbackup store in /tmp/zbacup-tar/zbackup

