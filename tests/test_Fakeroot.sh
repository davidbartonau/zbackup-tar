TMPDIR=/tmp/zbackup-tar/
TODO_BUG=1

echo TESTDATA $TESTDATA :: FUNCTIONROOT $FUNCTIONROOT
source $FUNCTIONROOT/test_Functions.sh


chown -R $TESTDATA/folder1/subfolder2
chmod go-rwx $TESTDATA/folder1/subfolder2
chmod go-rwx $TESTDATA/file2.txt
chmod u-wx $TESTDATA/file2.txt

backupAndRestoreDir backup05.tar backup05b.tar

cd $TESTDATA/ && find  -printf "%p, %U, %G, %m\n"  | sort > /tmp/test5b.testdata.perms
cd $TMPDIR/restored/ && find -printf "%p, %U, %G, %m\n"  | sort > /tmp/test5b.restored.perms


