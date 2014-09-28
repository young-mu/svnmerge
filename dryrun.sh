#!/bin/bash

# get dryrun.log by simulate merge using --dry-run parameter

brPath="/home/young/Merge/br"
tkPath="/home/young/Merge/trunk"
curPath="/home/young/Merge"
brUrl="http://localhost/svn/branches/br"

# get branch #rev that copied from trunk
echo "getting branch #rev ..."
brLog=`cd ${brPath} && svn log -q --stop-on-copy`
brRev=`echo "${brLog}" | tail -2 | head -1 | awk '{print $1}' | sed 's/r//'`
echo "branch #rev : ${brRev}"

# get dryrun
cd ${tkPath}
echo "getting dryrun.log ..."
svn merge ${brUrl}@${brRev} ${brUrl} . --dry-run > ${curPath}/dryrun.log
echo "dryrun.log is generated in the current directory successfully"
