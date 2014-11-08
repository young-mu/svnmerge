#!/bin/bash

# Usage :
# 1. replace the shell parameters like tkUrl and brUrl below
# 2. put dryrun.sh in the same directory as branch and trunk
# 3. execute "source ./dryrun.sh" to export all the functions
# 4. execute "./dryrun.sh" to get dryrun.log (whole) and svn logs in logs/
# 5. execute "merge <revBefore> <revAfter>" to get dryrun.log (part) in logs/
# 6. execute "merge <revBefore> <revAfter> exe" to start merge from branch to trunk 
# 7. solve file or tree conflicts by taking advantage of functions below 
# 8. test if needed and commit

curPath="/home/young/Merge"
tkPath="${curPath}/trunk"
brPath="${curPath}/branch"
tkqLog="${curPath}/logs/trunk_q.log"
brqLog="${curPath}/logs/branch_q.log"
dryrunLog="${curPath}/logs/dryrun.log"
tkUrl="http://localhost/svn/trunk"
brUrl="https://localhost/svn/branch"

# svn update of trunk and branch
function tbUpdate() 
{
    echo "enter" ${tkPath} 
    cd ${tkPath}
    svn up
    echo "enter" ${brPath} 
    cd ${brPath}
    svn up
    cd ${curPath}
}

# remove generated files
function rmFiles()
{
    if [[ -d ${curPath}/blames ]]; then
        echo "remove blames/ ..."
        rm -r ${curPath}/blames
    fi
    if [[ -d ${curPath}/diffs ]]; then
        echo "remove diffs/ ..."
        rm -r ${curPath}/diffs
    fi
    if [[ -d ${curPath}/logs ]]; then
        echo "remove logs/ ..."
        rm -r ${curPath}/logs
    fi
    if [[ -d ${curPath}/patches ]]; then
        echo "remove patches/ ..."
        rm -r ${curPath}/patches
    fi
}

# get branch #rev in which the designate content's line was removed (bisearch)
function getRevRemoved() 
{
    if [[ $# -ne 2 ]]; then
        echo "Usage : getRevRemoved <file> <line content>"
    else
        file=${1}
        content=${2}
        brRev=$(getRevCopied)
        cd ${brPath}
        headRev=`svn info | grep "Revision:" | awk '{print $2}'`
        left=${brRev}
        right=${headRev}
        while [[ ${left} -le ${right} ]]; do
            tmp=`expr ${left} + ${right}` &&  mid=`expr ${tmp} / 2 `
            if [[ `svn blame ${file} -r ${mid} | grep ${content}` ]]; then
                left=`expr ${mid} + 1`  
            else
                right=`expr ${mid} - 1`
            fi
        done
        cd ${curPath}
        echo "#rev = "${mid}
    fi
}

# get branch #rev that copied from trunk
function getRevCopied()
{
    brLog=`cd ${brPath} && svn log -q --stop-on-copy`
    brRev=`echo "${brLog}" | tail -2 | head -1 | awk '{print $1}' | sed 's/r//'`
    echo ${brRev}
}

# get logs of trunk and branch
function getLogs()
{
    if [[ ! -d ${curPath}/logs ]]; then
        mkdir ${curPath}/logs
    fi
    brRev=$(getRevCopied)
    cd ${tkPath}
    echo "enter" ${tkPath} 
    svn log -r HEAD:${brRev} > ${curPath}/logs/trunk.log
    svn log -q -r HEAD:${brRev} > ${curPath}/logs/trunk_q.log
    svn log -v -r HEAD:${brRev} > ${curPath}/logs/trunk_v.log
    echo "trunk.log / trunk_q.log / trunk_v.log are generated in logs/ successfully"
    cd ${brPath}
    echo "enter" ${brPath} 
    svn log -r HEAD:${brRev} > ${curPath}/logs/branch.log
    svn log -q -r HEAD:${brRev} > ${curPath}/logs/branch_q.log
    svn log -v -r HEAD:${brRev} > ${curPath}/logs/branch_v.log
    echo "branch.log / branch_q.log / branch_v.log are generated in logs/ successfully"
    cd ${curPath}
}

# get trunk #rev log (v - verbose)
function tkLog()
{
    if [ $# -ne 1 -a $# -ne 2 ]; then
        echo "Usage : tkLog <#rev> (v)"
    else
        tkRev=${1}
        cd ${tkPath}
        if [[ $# -eq 2 ]] && [[ $2 == 'v' ]]; then
            svn log -v -r ${tkRev}
        else
            svn log -r ${tkRev}
        fi
        cd ${curPath}
    fi
}

# get branch #rev log (v - verbose)
function brLog()
{
    if [ $# -ne 1 -a $# -ne 2 ]; then
        echo "Usage : brLog <#rev> (v)"
    else
        brRev=${1}
        cd ${brPath}
        if [[ $# -eq 2 ]] && [[ $2 == 'v' ]]; then
            svn log -v -r ${brRev}
        else
            svn log -r ${brRev}
        fi
        cd ${curPath}
    fi
}

# diff two trunk files (one is designated, the other is previous rev) 
function tDiff()
{
    if [[ $# -ne 2 ]]; then
        echo "Usage : tDiff <file> <#rev>"
    else
        diffFile=${1}
        curRev=${2}
        prevRev=`cat ${tkqLog} | grep ${curRev} -A2 | tail -1 | awk '{print $1}' | sed 's/r//'`
        svn diff ${tkUrl}/${diffFile} -r ${curRev}:${prevRev}
    fi
}

# diff two branch files (one is designated, the other is previous rev)
function bDiff()
{
    if [ $# -ne 2 -a $# -ne 3 ]; then
        echo "Usage : bDiff <file> <#rev> (p)"
    else
        diffFile=${1}
        curRev=${2}
        prevRev=`cat ${brqLog} | grep ${curRev} -A2 | tail -1 | awk '{print $1}' | sed 's/r//'`
        if [[ $# -eq 3 ]] && [[ $3 == 'p' ]]; then
            file=${diffFile//\//_}
            if [[ ! -d ${curPath}/patches ]]; then
                mkdir ${curPath}/patches
            fi
            svn diff ${brUrl}/${diffFile} -r ${curRev}:${prevRev} > ${curPath}/patches/${file}@${curRev}-${prevRev}.patch
        else
            svn diff ${brUrl}/${diffFile} -r ${curRev}:${prevRev}
        fi
    fi
}

# diff two revs in branch and remove mergeinfo's diffs
function brRevDiff()
{
    if [[ $# -ne 1 ]]; then
        echo "Usage : bDiff <#rev>"
    else
        curRev=${1}
        prevRev=`cat ${brqLog} | grep ${curRev} -A2 | tail -1 | awk '{print $1}' | sed 's/r//'`
        svn diff ${brUrl} -r ${curRev}:${prevRev} | egrep -v "svn:mergeinfo|Property changes|Reverse-merged|_____|^$"  
    fi
}


# diff two URL files (trunk & branch) and save the diff file
function tbDiff() 
{
    if [[ ! -d ${curPath}/diffs ]]; then
        mkdir ${curPath}/diffs
    fi
    if [[ $# -ne 1 ]]; then
        echo "Usage : tbDiff <file>"
    else
        diffFile=${1}
        tkFile=${tkUrl}/${diffFile}
        brFile=${brUrl}/${diffFile}
        # replace '/' with '_' in the file name
        localFile=${1//\//_}
        svn diff ${tkFile} ${brFile} > ${curPath}/diffs/${localFile}
        echo "'${localFile}' diff file is generated in diffs/ successfully."
    fi
}

# blame two URL blame (trunk & branch) and save the blame file
function tbBlame()
{
    if [[ ! -d ${curPath}/blames ]]; then
        mkdir ${curPath}/blames
    fi
    if [[ $# -ne 1 ]]; then
        echo "Usage : tbBlame <file>"
    else
        blameFile=${1}
        tkFile=${tkUrl}/${blameFile}
        brFile=${brUrl}/${blameFile}
        # replace '/' with '_' in the file name and add prefix 'b-tk' or 'b-br' 
        tkLocalFile="b-tk-${1//\//_}"
        brLocalFile="b-br-${1//\//_}"
        svn blame ${tkFile} > ${curPath}/blames/${tkLocalFile}
        svn blame ${brFile} > ${curPath}/blames/${brLocalFile}
        echo "'${tkLocalFile}' blame file is generated in blames/ successfully."
        echo "'${brLocalFile}' blame file is generated in blames/ successfully."
    fi
}

# merge one diff (#rev1 to #rev2) of branch to trunk
function merge()
{
    if [[ ! -d ${curPath}/logs ]]; then
        mkdir ${curPath}/logs
    fi
    if [ $# -ne 2 -a $# -ne 3 ]; then
        echo "Usage : merge <#brRevOld> <#brRevNew> (exe)"
    else
        revOld=${1}
        revNew=${2}
        if [[ $# -eq 3 ]] && [[ ${3} == 'exe' ]]; then
            cd ${tkPath}
            svn merge -r ${revOld}:${revNew} ${brUrl} .
        else    
            cd ${tkPath}
            mergeFile="m${revOld}_${revNew}"
            svn merge -r ${revOld}:${revNew} ${brUrl} . --dry-run > ${curPath}/logs/${mergeFile}
            echo "${mergeFile} is generated in logs/ successfully."
            cd ${curPath}
        fi
    fi
}

if [[ $0 == "./dryrun.sh" ]]; then
    mkdir logs diffs blames
    # get dryrun
    cd ${tkPath}
    echo "getting dryrun.log ..."
    brRev=$(getRevCopied)
    svn merge ${brUrl}@${brRev} ${brUrl} . --dry-run > ${curPath}/logs/dryrun.log
    echo "dryrun.log is generated in logs/ successfully"
    echo "-----"
    # get trunk and branch logs
    echo "getting trunk and branch logs ..."
    getLogs
    echo "-----"
    # get conflict files from dryrun.log
    cd ${curPath}
    cRawFiles=`sed -n '/^C/p' ${dryrunLog}`
    cFiles=`echo "${cRawFiles}" | awk '{print $2}'` 
    # diff conflict file and then save diff file 
    i=0
    for cFile in ${cFiles}; do
        let i++ 
        tbDiff ${cFile}
    done
    echo -e "\n${i} files"
fi
