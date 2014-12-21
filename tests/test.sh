#!/bin/bash
#
# Ensure zbackup-tar is in your path:
# export PATH=$PATH:/home/david/Projects/zbackup-tar
#
# Usage:
# test.sh /home/david/Projects/zbackup-tar/tests/testdata

TMPDIR=/tmp/zbackup-tar/
TESTDATA=$1

rm -rf $TMPDIR
mkdir -pv $TMPDIR/zbackup $TMPDIR/restored

zbackup init --non-encrypted $TMPDIR/zbackup/
find $TESTDATA -name "*.txt" -print0 | xargs -0 rm -v


function backupAndRestoreDir ()
{
    PREVNAME=$1
    BACKUPNAME=$2

    if [ -z "$PREVNAME" ]; then
        PREVBACKUP=""
    else
        PREVBACKUP=$TMPDIR/zbackup/backups/$PREVNAME
    fi
    
    echo PREVBACKUP $PREVBACKUP NEWBACKUP $TMPDIR/zbackup/backups/$BACKUPNAME
    zbackup-tar create --previousBackup "$PREVBACKUP" --newBackup $TMPDIR/zbackup/backups/$BACKUPNAME --maxAge 0.05 --maxAgeJitter 0.03 $TESTDATA/

    echo Restore $BACKUPNAME

    cd $TMPDIR/restored/
    rm -rf $TMPDIR/restored/*

    zbackup-tar restore --backup $TMPDIR/zbackup/backups/$BACKUPNAME

    echo Checking $BACKUPNAME

    diff -rq $TESTDATA/ $TMPDIR/restored/

    if [ "$?" -eq 0 ]; then
        echo SUCCESS $BACKUPNAME is the same
    else
        echo FAIL Restoring $BACKUPNAME
        exit 1
    fi

    zbackup restore $TMPDIR/zbackup/backups/$BACKUPNAME.manifest > /tmp/$BACKUPNAME.manifest
}


function sleepAvoidCollision ()
{
    echo "Sleeping for 10 seconds so we don't get date collisions"
    sleep 10 
}



echo "######## Backup 1 - Initial Backup ########"
backupAndRestoreDir "" backup01.tar
sleepAvoidCollision



"######## Backup 2 - No Changes ########"
backupAndRestoreDir backup01.tar backup02.tar

diff /tmp/backup01.tar.manifest /tmp/backup02.tar.manifest

if [ "$?" -eq 0 ]; then
    echo SUCCESS Backup manifest 1 and 2 are identical
else
    echo FAIL Restoring backup 1
    return
fi

sleepAvoidCollision




echo "######## Backup 3 - A New File ########"
date > $TESTDATA/file.txt

backupAndRestoreDir backup02.tar backup03.tar
sleepAvoidCollision



echo "######## Backup 4 - Changed Files ########"
date > $TESTDATA/file.txt
date > $TESTDATA/folder2/file.txt

backupAndRestoreDir backup03.tar backup04.tar
sleepAvoidCollision



echo "######## Backup 5 - Removed Files ########"
find $TESTDATA -name "*.txt" -print0 | xargs -0 rm -v

backupAndRestoreDir backup04.tar backup05.tar
sleepAvoidCollision




echo "######## Backup 6 - Sleep for 2 mins ########"

echo "Sleeping for 2 minutes to freshen some files (0.05h = 3 mins +/- 1.8 mins i.e. 1.2 - 4.8 mins"
sleep 120 

backupAndRestoreDir backup05.tar backup06.tar

diff /tmp/backup05.tar.manifest /tmp/backup06.tar.manifest

if [ "$?" -eq 0 ]; then
    echo FAIL Manifests are identical, should have been reloaded
    return
else
    echo SUCCESS Manifest has changed
fi



echo "######## Backup 7 - Sleep for 1 mins ########"

echo "Sleeping for 1 minutes to freshen some files"
sleep 60 

backupAndRestoreDir backup06.tar backup07.tar

diff /tmp/backup06.tar.manifest /tmp/backup07.tar.manifest

if [ "$?" -eq 0 ]; then
    echo FAIL Manifests are identical, should have been reloaded
    return
else
    echo SUCCESS Manifest has changed
fi

sleepAvoidCollision



echo "######## Backup 8 - Add txt files ########"
date > $TESTDATA/file.txt
date > $TESTDATA/folder2/file.txt

backupAndRestoreDir backup07.tar backup08.tar
sleepAvoidCollision



echo "######## Backup 9 - Exclude txt files ########"
rm -rf $TMPDIR/restored/*
echo Initial backup 9
zbackup-tar create --previousBackup $TMPDIR/zbackup/backups/backup08.tar --newBackup $TMPDIR/zbackup/backups/backup09.tar --maxAge 0.05 --maxAgeJitter 0.03 --exclude "*.txt" $TESTDATA/


echo Restore backup 9
cd $TMPDIR/restored/
zbackup-tar restore --backup $TMPDIR/zbackup/backups/backup09.tar

zbackup restore $TMPDIR/zbackup/backups/backup09.tar.manifest > /tmp/backup09.tar.manifest

echo Checking backup 9
diff -rq $TESTDATA/ $TMPDIR/restored/

if [ "$?" -eq 0 ]; then
    echo FAIL txt files should be different
    return
else
    echo SUCCESS backup 9 is different
fi


find $TESTDATA/ -name "*.txt" -print0 | xargs -0 rm -v

diff -rq $TESTDATA/ $TMPDIR/restored/

if [ "$?" -eq 0 ]; then
    echo SUCCESS After removing txt files, backup should be the same
else
    echo FAIL backup files were different
    return
fi


echo "Sleeping for 10 seconds so we don't get date collisions"
sleep 10 




