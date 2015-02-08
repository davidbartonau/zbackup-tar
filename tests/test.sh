#!/bin/bash
#
# Ensure zbackup-tar is in your path:
# export PATH=$PATH:/home/david/Projects/zbackup-tar
#
# Usage:
# test.sh /home/david/Projects/zbackup-tar/tests/testdata

SCRIPTNAME=`readlink -f $0`
export FUNCTIONROOT=`dirname $SCRIPTNAME`
export TMPDIR=/tmp/zbackup-tar/
export TESTDATA=$1
REFRESHCYCLES=5
TODO_BUG=1

source $FUNCTIONROOT/test_Functions.sh


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
    checkForSuccess "SUCCESS $BACKUPNAME backed up" "FAIL zbackup-tar failed"

    cd $TMPDIR/restored/
    rm -rf $TMPDIR/restored/*

    zbackup-tar restore --zbackupArgs "--password-file $TMPDIR/password" --backup $TMPDIR/zbackup_encrypted/backups/backup01.tar
    checkForSuccess "SUCCESS $BACKUPNAME restored" "FAIL zbackup-tar restore failed"

    diff -rq --no-dereference $TESTDATA/ $TMPDIR/restored/
    checkForSuccess "SUCCESS $BACKUPNAME is the same" "FAIL Restoring $BACKUPNAME"
}



function test1SameDir ()
{
    logResult "######## Backup 1 - Same Dir ########"

    BACKUPNAME=backup01_samedir.tar

    cd $TESTDATA/
    echo "I am now in " `pwd`

    zbackup-tar create --previousBackup "" --newBackup $TMPDIR/zbackup/backups/$BACKUPNAME .
    checkForSuccess "SUCCESS $BACKUPNAME backed up" "FAIL zbackup-tar failed"

    cd $TMPDIR/restored/
    rm -rf $TMPDIR/restored/*

    zbackup-tar restore --backup $TMPDIR/zbackup/backups/$BACKUPNAME
    checkForSuccess "SUCCESS $BACKUPNAME restored" "FAIL zbackup-tar restore failed" 

    restoreAndCheck

    sleepAvoidCollision
}



function test2 ()
{
    logResult "######## Backup 2 - No Changes ########"
    export REFRESHCYCLES=0
    backupAndRestoreDir backup01.tar backup02.tar
    export REFRESHCYCLES=5

    diff <(tail -n +2 /tmp/backup01.tar.manifest) <(tail -n +2 /tmp/backup02.tar.manifest)

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



function test5b ()
{
    logResult "######## Backup 5b - File permissions ########"

    fakeroot -u $FUNCTIONROOT//test_Fakeroot.sh

    diff /tmp/test5b.testdata.perms /tmp/test5b.restored.perms
    checkForSuccess "SUCCESS Permissions match" "FAIL Permissions do not match"
    

    sleepAvoidCollision
}



function test6 ()
{
    logResult "######## Test 6 - Moving the backup ########"
    export BACKUP=06
    backupAndRestoreDir backup05b.tar backup$BACKUP.tar

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
    date > $TESTDATA/file.txt
    echo Initial backup $BACKUP
    zbackup-tar create --previousBackup $TMPDIR/zbackup/backups/backup08.tar --newBackup $TMPDIR/zbackup/backups/backup$BACKUP.tar --refreshCycles 5 --exclude "*.txt" $TESTDATA/


    echo Restore backup $BACKUP
    cd $TMPDIR/restored/
    zbackup-tar restore --backup $TMPDIR/zbackup/backups/backup$BACKUP.tar

    zbackup restore --silent $TMPDIR/zbackup/backups/backup$BACKUP.tar.manifest > /tmp/backup$BACKUP.tar.manifest

    echo Checking backup $BACKUP
    diff -rq --no-dereference $TESTDATA/ $TMPDIR/restored/

    checkForFailure "FAIL txt files should be different" "SUCCESS backup $BACKUP is different"

    find $TESTDATA/ -name "*.txt" -print0 | xargs -0 rm -v

    diff -rq --no-dereference $TESTDATA/ $TMPDIR/restored/

    checkForSuccess "SUCCESS After removing txt files, backup should be the same" "FAIL backup files were different" 

    sleepAvoidCollision
}



function test9b ()
{
    logResult "######## Backup 9b - Exclude multiple extensions ########"
    export BACKUP=09b
    rm -rf $TMPDIR/restored/*
    mkdir -v $TESTDATA/excludedir/
    date > $TESTDATA/file.txt
    date > $TESTDATA/file.exclude
    date > $TESTDATA/excludedir/test.sh

    echo Initial backup $BACKUP
    zbackup-tar create --previousBackup $TMPDIR/zbackup/backups/backup08.tar --newBackup $TMPDIR/zbackup/backups/backup$BACKUP.tar --refreshCycles 5 --exclude "*.txt" --exclude "*.exclude" --exclude "excludedir/" $TESTDATA/


    echo Restore backup $BACKUP
    cd $TMPDIR/restored/
    zbackup-tar restore --backup $TMPDIR/zbackup/backups/backup$BACKUP.tar

    zbackup restore --silent $TMPDIR/zbackup/backups/backup$BACKUP.tar.manifest > /tmp/backup$BACKUP.tar.manifest

    echo Checking backup $BACKUP
    diff -rq --no-dereference $TESTDATA/ $TMPDIR/restored/

    checkForFailure "FAIL txt files should be different" "SUCCESS backup $BACKUP is different"

    find $TESTDATA/ -name "*.txt" -print0 | xargs -0 rm -v
    find $TESTDATA/ -name "*.exclude" -print0 | xargs -0 rm -v
    find $TESTDATA/ -name "excludedir" -print0 | xargs -0 rm -rfv

    diff -rq --no-dereference $TESTDATA/ $TMPDIR/restored/

    checkForSuccess "SUCCESS After removing txt and ,v and subdir1/, backup should be the same" "FAIL backup files were different" 

    sleepAvoidCollision
}



function test10 ()
{
    logResult "######## Backup 10 - Exclude subfolder1/ files ########"
    export BACKUP=10
    rm -rf $TMPDIR/restored/*
    echo Initial backup $BACKUP
    zbackup-tar create --previousBackup $TMPDIR/zbackup/backups/backup09.tar --newBackup $TMPDIR/zbackup/backups/backup$BACKUP.tar --refreshCycles 5 --exclude "subfolder1/" $TESTDATA/


    echo Restore backup $BACKUP
    cd $TMPDIR/restored/
    zbackup-tar restore --backup $TMPDIR/zbackup/backups/backup$BACKUP.tar

    zbackup restore --silent $TMPDIR/zbackup/backups/backup$BACKUP.tar.manifest > /tmp/backup$BACKUP.tar.manifest

    echo Checking backup $BACKUP
    diff -rq --no-dereference $TESTDATA/ $TMPDIR/restored/ > /tmp/backup$BACKUP.diff

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

    zbackup-tar create --previousBackup $TMPDIR/zbackup/backups/backup10.tar --newBackup $TMPDIR/zbackup/backups/backup$BACKUP.tar --refreshCycles 5 $TESTDATA/

    checkForFailure "FAIL - backup should have FAILED $BACKUP" "SUCCESS Storing the backup returned a non-0 error code"

    chmod --reference=/tmp/zbackup-tar/zbackup/bundles /tmp/zbackup-tar/zbackup/index/

    zbackup-tar create --previousBackup $TMPDIR/zbackup/backups/backup10.tar --newBackup $TMPDIR/zbackup/backups/backup$BACKUP.tar --refreshCycles 5 $TESTDATA/

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
    zbackup-tar create --previousBackup $TMPDIR/zbackup/backups/backup11.tar --newBackup $TMPDIR/zbackup/backups/backup$BACKUP.tar $TESTDATA/ > /tmp/backup$BACKUP.stdout

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

    diff -rq --no-dereference $TESTDATA/folder1/ $TMPDIR/restored/folder1/

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

    backupAndRestoreDir backup15.tar backup$BACKUP.tar

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


echo Executing Unit Tests in $FUNCTIONROOT
find $TESTDATA -name "*.txt" -print0 | xargs -0 rm -v
find $TESTDATA -name "*.link" -print0 | xargs -0 rm -v
mkdir -v $TESTDATA/empty

chmod --reference=/tmp/zbackup-tar/zbackup/bundles /tmp/zbackup-tar/zbackup/index/
rm -rf $TMPDIR
mkdir -pv $TMPDIR/zbackup $TMPDIR/restored

zbackup init --non-encrypted $TMPDIR/zbackup/

test1
test1SameDir
test1Encrypted
test2
test3
test4
test5
test5b
test6
test7
test8
test9
test9b
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

grep backup01 /tmp/backup$BACKUP.tar.manifest

checkForFailure "FAIL backup01 is in use" "SUCCESS backup01 is no longer in use"


find $TESTDATA -name "*.txt" -print0 | xargs -0 rm -v

