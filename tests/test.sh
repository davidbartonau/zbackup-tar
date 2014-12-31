#!/bin/bash
#
# Ensure zbackup-tar is in your path:
# export PATH=$PATH:/home/david/Projects/zbackup-tar
#
# Usage:
# test.sh /home/david/Projects/zbackup-tar/tests/testdata

TMPDIR=/tmp/zbackup-tar/
TESTDATA=$1
TODO_BUG=1


logResult()
{
    echo "[UNIT TEST] $1"
}


logFailResult()
{
    echo "[UNIT TEST] $1"  1>&2
}


checkForSuccess ()
{
   if [ "$?" -eq 0 ]; then
        logResult "$1"
    else
        logFailResult "$2"

        if [ -z "$3" ]; then
            exit 1
        else
            logFailResult "KNOWN BUG - Supressing Failure"
        fi
    fi
}


checkForFailure ()
{
   if [ "$?" -eq 0 ]; then
        logFailResult "$1"

        if [ -z "$3" ]; then
            exit 1
        else
            logFailResult "KNOWN BUG - Supressing Failure"
        fi
    else
        logResult "$2"
    fi
}


function backupAndRestoreDir ()
{
    PREVNAME=$1
    BACKUPNAME=$2
    LOCAL_TODO_BUG=$3

    if [ -z "$PREVNAME" ]; then
        PREVBACKUP=""
    else
        PREVBACKUP=$TMPDIR/zbackup/backups/$PREVNAME
    fi
    
    echo PREVBACKUP $PREVBACKUP NEWBACKUP $TMPDIR/zbackup/backups/$BACKUPNAME
    zbackup-tar create --previousBackup "$PREVBACKUP" --newBackup $TMPDIR/zbackup/backups/$BACKUPNAME --maxAge 0.03 --maxAgeJitter 0.02 $TESTDATA/
    checkForSuccess "SUCCESS $BACKUPNAME backed up" "FAIL zbackup-tar failed" $LOCAL_TODO_BUG

    echo Restore $BACKUPNAME

    cd $TMPDIR/restored/
    rm -rf $TMPDIR/restored/*

    zbackup-tar restore --backup $TMPDIR/zbackup/backups/$BACKUPNAME
    checkForSuccess "SUCCESS $BACKUPNAME restored" "FAIL zbackup-tar restore failed" $LOCAL_TODO_BUG

    echo Checking $BACKUPNAME

    diff -rq $TESTDATA/ $TMPDIR/restored/
    checkForSuccess "SUCCESS $BACKUPNAME is the same" "FAIL Restoring $BACKUPNAME" $LOCAL_TODO_BUG

    zbackup restore --silent $TMPDIR/zbackup/backups/$BACKUPNAME.manifest > /tmp/$BACKUPNAME.manifest
}


function longSleep ()
{
    SLEEP_PERIOD=$1
    SLEEP_MESSAGE=$2

    echo -n "Sleeping for $SLEEP_PERIOD $SLEEP_MESSAGE"

    for i in `seq 1 $SLEEP_PERIOD`; do
        sleep 1

        if [ $((i % 5)) -eq 0 ]; then
            echo -n $i
        else
            echo -n .
        fi
    done;

    echo DONE
}



function sleepAvoidCollision ()
{
    SLEEP_PERIOD=3

    echo -n "Sleeping for $SLEEP_PERIOD seconds so we don't get date collisions "
    for i in `seq 1 $SLEEP_PERIOD`; do
        sleep 1
        echo -n .
    done;

    echo DONE
}


function test1 ()
{
    logResult "######## Backup 1 - Initial Backup ########"
    backupAndRestoreDir "" backup01.tar
    sleepAvoidCollision
}



function test1Encrypted ()
{
    logResult "######## Backup 1 Encrypted - Encrypted backups ########"
    echo mypassword > $TMPDIR/password

    zbackup init --password-file $TMPDIR/password $TMPDIR/zbackup_encrypted/

    zbackup-tar create --zbackupArgs "--password-file $TMPDIR/password" --previousBackup "" --newBackup $TMPDIR/zbackup_encrypted/backups/backup01.tar $TESTDATA/
    checkForSuccess "SUCCESS $BACKUPNAME backed up" "FAIL zbackup-tar failed" $TODO_BUG

    cd $TMPDIR/restored/
    rm -rf $TMPDIR/restored/*

    zbackup-tar restore --zbackupArgs "--password-file $TMPDIR/password" --backup $TMPDIR/zbackup_encrypted/backups/backup01.tar
    checkForSuccess "SUCCESS $BACKUPNAME restored" "FAIL zbackup-tar restore failed" $TODO_BUG

    diff -rq $TESTDATA/ $TMPDIR/restored/
    checkForSuccess "SUCCESS $BACKUPNAME is the same" "FAIL Restoring $BACKUPNAME" $TODO_BUG
}



function test2 ()
{
    logResult "######## Backup 2 - No Changes ########"
    backupAndRestoreDir backup01.tar backup02.tar

    diff /tmp/backup01.tar.manifest /tmp/backup02.tar.manifest

    checkForSuccess "SUCCESS Backup manifest 1 and 2 are identical" "FAIL manifest 1 and 2 are different"

    sleepAvoidCollision
}



function test3 ()
{
    logResult "######## Backup 3 - A New File ########"
    date > $TESTDATA/file.txt

    backupAndRestoreDir backup02.tar backup03.tar
    sleepAvoidCollision
}


function test4 ()
{
    logResult "######## Backup 4 - Changed Files ########"
    date > $TESTDATA/file.txt
    date > $TESTDATA/folder2/file.txt

    backupAndRestoreDir backup03.tar backup04.tar
    sleepAvoidCollision
}



function test5 ()
{
    logResult "######## Backup 5 - Removed Files ########"
    find $TESTDATA -name "*.txt" -print0 | xargs -0 rm -v

    backupAndRestoreDir backup04.tar backup05.tar
    sleepAvoidCollision
}



function test6 ()
{
    logResult "######## Test 6 - Moving the backup ########"
    export BACKUP=06
    backupAndRestoreDir backup05.tar backup$BACKUP.tar

    mkdir -pv $TMPDIR/foo/bar/
    mv $TMPDIR/zbackup $TMPDIR/foo/bar/

    echo Restore backup $BACKUP
    cd $TMPDIR/restored/
    zbackup-tar restore --backup $TMPDIR/foo/bar/zbackup/backups/backup$BACKUP.tar

    echo Checking backup $BACKUP
    diff -rq $TESTDATA/ $TMPDIR/restored/

    checkForSuccess "SUCCESS $BACKUP is the same" "FAIL $BACKUP is differente"

    mv $TMPDIR/foo/bar/zbackup $TMPDIR/

    sleepAvoidCollision
}



function test7 ()
{
    logResult "######## Test 7 - Handling errors ########"
    export BACKUP=07
    backupAndRestoreDir backup06.tar backup$BACKUP.tar

    chmod gou-rwx /tmp/zbackup-tar/zbackup/index/

    echo Restore backup $BACKUP AFTER remiving permissions
    cd $TMPDIR/restored/
    zbackup-tar restore --backup $TMPDIR/zbackup/backups/backup$BACKUP.tar

    checkForFailure "FAIL - backup should have FAILED $BACKUP" "SUCCESS Restoring the backup returned a non-0 error code"

    chmod --reference=/tmp/zbackup-tar/zbackup/bundles /tmp/zbackup-tar/zbackup/index/

    sleepAvoidCollision
}




function test8 ()
{
    logResult "######## Backup 8 - Add txt files ########"
    date > $TESTDATA/file.txt
    date > $TESTDATA/folder2/file.txt

    backupAndRestoreDir backup07.tar backup08.tar
    sleepAvoidCollision
}



function test9 ()
{
    logResult "######## Backup 9 - Exclude txt files ########"
    export BACKUP=09
    rm -rf $TMPDIR/restored/*
    echo Initial backup $BACKUP
    zbackup-tar create --previousBackup $TMPDIR/zbackup/backups/backup08.tar --newBackup $TMPDIR/zbackup/backups/backup$BACKUP.tar --maxAge 0.05 --maxAgeJitter 0.03 --exclude "*.txt" $TESTDATA/


    echo Restore backup $BACKUP
    cd $TMPDIR/restored/
    zbackup-tar restore --backup $TMPDIR/zbackup/backups/backup$BACKUP.tar

    zbackup restore --silent $TMPDIR/zbackup/backups/backup$BACKUP.tar.manifest > /tmp/backup$BACKUP.tar.manifest

    echo Checking backup $BACKUP
    diff -rq $TESTDATA/ $TMPDIR/restored/

    checkForFailure "FAIL txt files should be different" "SUCCESS backup $BACKUP is different"

    find $TESTDATA/ -name "*.txt" -print0 | xargs -0 rm -v

    diff -rq $TESTDATA/ $TMPDIR/restored/

    checkForSuccess "SUCCESS After removing txt files, backup should be the same" "FAIL backup files were different"

    sleepAvoidCollision
}



function test10 ()
{
    logResult "######## Backup 10 - Exclude subfolder1/ files ########"
    export BACKUP=10
    rm -rf $TMPDIR/restored/*
    echo Initial backup $BACKUP
    zbackup-tar create --previousBackup $TMPDIR/zbackup/backups/backup09.tar --newBackup $TMPDIR/zbackup/backups/backup$BACKUP.tar --maxAge 0.05 --maxAgeJitter 0.03 --exclude "subfolder1/" $TESTDATA/


    echo Restore backup $BACKUP
    cd $TMPDIR/restored/
    zbackup-tar restore --backup $TMPDIR/zbackup/backups/backup$BACKUP.tar

    zbackup restore --silent $TMPDIR/zbackup/backups/backup$BACKUP.tar.manifest > /tmp/backup$BACKUP.tar.manifest

    echo Checking backup $BACKUP
    diff -rq $TESTDATA/ $TMPDIR/restored/ > /tmp/backup$BACKUP.diff

    checkForFailure "FAIL txt files should be different" "SUCCESS backup $BACKUP is different"

    grep -v subfolder1 /tmp/backup$BACKUP.diff

    checkForFailure "FAIL There should be no lines not matching subfolder1/" "SUCCESS backup is the same after excluding subfolder1/"

    sleepAvoidCollision
}



function test11 ()
{
    logResult "######## Test 11 - Handling errors backing up ########"
    export BACKUP=11
    chmod gou-rwx /tmp/zbackup-tar/zbackup/index/

    zbackup-tar create --previousBackup $TMPDIR/zbackup/backups/backup10.tar --newBackup $TMPDIR/zbackup/backups/backup$BACKUP.tar --maxAge 0.03 --maxAgeJitter 0.02 $TESTDATA/

    checkForFailure "FAIL - backup should have FAILED $BACKUP" "SUCCESS Storing the backup returned a non-0 error code"

    chmod --reference=/tmp/zbackup-tar/zbackup/bundles /tmp/zbackup-tar/zbackup/index/

    zbackup-tar create --previousBackup $TMPDIR/zbackup/backups/backup10.tar --newBackup $TMPDIR/zbackup/backups/backup$BACKUP.tar --maxAge 0.03 --maxAgeJitter 0.02 $TESTDATA/

    checkForSuccess "SUCCESS - backup should have SUCCEEDED $BACKUP" "FAIL Backing up returned a non-0 error code"

    sleepAvoidCollision
}



function test12 ()
{
    logResult "######## Test 12 - Ensuring backup output ########"
    export BACKUP=12

    date > $TESTDATA/file.txt
    date > $TESTDATA/folder2/file.txt
    touch $TESTDATA/document.pdf 

    # Extend maxAge so we don't freshen any files
    zbackup-tar create --previousBackup $TMPDIR/zbackup/backups/backup11.tar --newBackup $TMPDIR/zbackup/backups/backup$BACKUP.tar --maxAge 10 --maxAgeJitter 0.02 $TESTDATA/ > /tmp/backup$BACKUP.stdout

    diff -w /tmp/backup$BACKUP.stdout $TESTDATA/../results/backup$BACKUP.stdout

    checkForSuccess "SUCCESS - Output should be the same $BACKUP" "FAILURE Output is not the same as the sample" 

    sleepAvoidCollision
}



# Expected output is:
# fileX     EXTRACTED from backups/blah.tar
# fileY     EXTRACTED from backups/blahX.tar
# where backupNN.tar is the tar file where the file resides.
# The files are listed on the order they are extracted, so they should be listed clustered by tarfile and then in the order they were tarred
function test13 ()
{
    logResult "######## Test 13 - Ensuring restore output ########"
    export BACKUP=13

    backupAndRestoreDir backup12.tar backup13.tar

    cd $TMPDIR/restored/
    rm -rf $TMPDIR/restored/*
    zbackup-tar restore --backup $TMPDIR/zbackup/backups/backup$BACKUP.tar > /tmp/backup$BACKUP.stdout

    # Sort the output of the command by filename, since the output is NOT sorted
    sort /tmp/backup$BACKUP.stdout | sed -e "s/backup[0-9][0-9].tar/backupNN.tar/g" > /tmp/backup$BACKUP.stdout.massaged
    diff -w /tmp/backup$BACKUP.stdout.massaged $TESTDATA/../results/backup$BACKUP.stdout

    checkForSuccess "SUCCESS - Output should be the same $BACKUP" "FAILURE Output is not the same as the sample" 

    sleepAvoidCollision
}


function test14 ()
{
    logResult "######## Test 14 - Partial restores - directories ########"
    export BACKUP=14

    backupAndRestoreDir backup13.tar backup$BACKUP.tar

    cd $TMPDIR/restored/
    rm -rf $TMPDIR/restored/*
    zbackup-tar restore --backup $TMPDIR/zbackup/backups/backup$BACKUP.tar folder1/

    diff -rq $TESTDATA/folder1/ $TMPDIR/restored/folder1/

    checkForSuccess "SUCCESS - folder1 is the same" "FAILURE folder1 is different"

    if [ -d "$TMPDIR/restored/folder2" ]; then
        logFailResult "FAIL folder2 should not have been restored"
        exit 1
    else
        logResult "SUCCESS folder2 was not restored"
    fi

    sleepAvoidCollision
}


function test15 ()
{
    logResult "######## Test 15 - Partial restores - files ########"
    export BACKUP=15

    backupAndRestoreDir backup14.tar backup$BACKUP.tar

    cd $TMPDIR/restored/
    rm -rf $TMPDIR/restored/*
    zbackup-tar restore --backup $TMPDIR/zbackup/backups/backup$BACKUP.tar file.txt

    find -type f | sort > /tmp/backup$BACKUP.list
    diff -wB /tmp/backup$BACKUP.list $TESTDATA/../results/backup$BACKUP.list

    checkForSuccess "SUCCESS - files are the same" "FAILURE files are different"

    sleepAvoidCollision
}



function test16 ()
{
    logResult "######## Test 16 - links (broken and working) ########"
    export BACKUP=16

    ln -sT /dev/broken $TESTDATA/broken.link
    ln -sT /etc/init.d $TESTDATA/initd.link

    backupAndRestoreDir backup15.tar backup$BACKUP.tar $TODO_BUG

    find $TESTDATA -name "*.link" -print0 | xargs -0 rm -v
    sleepAvoidCollision
}






function testSleep ()
{
    PREVBACKUP=$1
    BACKUP=$2

    logResult "######## Backup $BACKUP / $PREVBACKUP - Sleep for 1 mins ########"

    longSleep 60 "To freshen files"

    backupAndRestoreDir backup$PREVBACKUP.tar backup$BACKUP.tar

    diff /tmp/backup$PREVBACKUP.tar.manifest /tmp/backup$BACKUP.tar.manifest

    checkForFailure "FAIL Manifests are identical, should have been reloaded" "SUCCESS Manifest has changed"

    sleepAvoidCollision
}



find $TESTDATA -name "*.txt" -print0 | xargs -0 rm -v
find $TESTDATA -name "*.link" -print0 | xargs -0 rm -v

chmod --reference=/tmp/zbackup-tar/zbackup/bundles /tmp/zbackup-tar/zbackup/index/
rm -rf $TMPDIR
mkdir -pv $TMPDIR/zbackup $TMPDIR/restored

zbackup init --non-encrypted $TMPDIR/zbackup/


test1
test1Encrypted
test2
test3
test4
test5
test6
test7
test8
test9
test10
test11
test12
test13
test14
test15
test16
LASTTEST=16

for i in `seq 1 3`; do
    PREVBACKUP=$((LASTTEST + i - 1))
    BACKUP=$((LASTTEST + i))

    testSleep $PREVBACKUP $BACKUP
done;



find $TESTDATA -name "*.txt" -print0 | xargs -0 rm -v

