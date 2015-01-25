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
    local PREVNAME=$1
    local BACKUPNAME=$2
    local LOCAL_TODO_BUG=$3
    local PREVBACKUP

    if [ -z "$PREVNAME" ]; then
        PREVBACKUP=""
    else
        PREVBACKUP=$TMPDIR/zbackup/backups/$PREVNAME
    fi
    
    echo PREVBACKUP $PREVBACKUP NEWBACKUP $TMPDIR/zbackup/backups/$BACKUPNAME
    zbackup-tar create --previousBackup "$PREVBACKUP" --newBackup $TMPDIR/zbackup/backups/$BACKUPNAME --maxAge 0.03 --maxAgeJitter 0.02 $TESTDATA/
    checkForSuccess "SUCCESS $BACKUPNAME backed up" "FAIL zbackup-tar failed" $LOCAL_TODO_BUG

    restoreAndCheck $LOCAL_TODO_BUG
}


function restoreAndCheck ()
{
    local LOCAL_TODO_BUG=$1

    echo Restore $BACKUPNAME

    cd $TMPDIR/restored/
    rm -rf $TMPDIR/restored/*

    zbackup restore --silent $TMPDIR/zbackup/backups/$BACKUPNAME.manifest > /tmp/$BACKUPNAME.manifest
    zbackup-tar restore --backup $TMPDIR/zbackup/backups/$BACKUPNAME
    checkForSuccess "SUCCESS $BACKUPNAME restored" "FAIL zbackup-tar restore failed" $LOCAL_TODO_BUG

    echo Checking $BACKUPNAME

    diff -rq  --no-dereference $TESTDATA/ $TMPDIR/restored/
    checkForSuccess "SUCCESS $BACKUPNAME is the same" "FAIL Restoring $BACKUPNAME" $LOCAL_TODO_BUG
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


