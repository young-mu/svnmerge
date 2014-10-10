#!/bin/bash

# 1. get dryrun.log by simulate merge using --dry-run parameter
# 2. get trunk and branch logs (normal, quiet and verbose) to logs/
# 3. get conflict files from logs/dryrun.log and diff & save them to diffs/

curPath="/home/young/Merge"
tkPath="${curPath}/trunk"
brPath="${curPath}/branch"
tkqLog="${curPath}/logs/trunk_q.log"
brqLog="${curPath}/logs/branch_q.log"
dryrunLog="${curPath}/logs/dryrun.log"
tkUrl="http://localhost/svn/trunk"
brUrl="https://localhost/svn/branch"

# remove generated files
function rmFiles()
{
	echo "remove blames/ ..."
	rm -r ${curPath}/blames
	echo "remove diffs/ ..."
	rm -r ${curPath}/diffs
	echo "remove logs/ ..."
	rm -r ${curPath}/logs
}

# get branch #rev in which the designate content's line was removed (bisearch)
function getRevRemoved() 
{
	if [[ $# -ne 2 ]]; then
		echo "Usage : getRevRemoved <file> <line content>"
	else
		file=${1}
		content=${2}
		getRevCopied && brRev=${?}
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
	return ${brRev}
}

# get logs of trunk and branch
function getLogs()
{
	getRevCopied && brRev=${?}
	cd ${tkPath}
	echo "enter " ${tkPath} 
	svn log -r HEAD:${brRev} > ${curPath}/logs/trunk.log
	svn log -q -r HEAD:${brRev} > ${curPath}/logs/trunk_q.log
	svn log -v -r HEAD:${brRev} > ${curPath}/logs/trunk_v.log
	echo "trunk.log / trunk_q.log / trunk_v.log are generated in logs/ successfully"
	cd ${brPath}
	echo "enter " ${brPath} 
	svn log -r HEAD:${brRev} > ${curPath}/logs/branch.log
	svn log -q -r HEAD:${brRev} > ${curPath}/logs/branch_q.log
	svn log -v -r HEAD:${brRev} > ${curPath}/logs/branch_v.log
	echo "branch.log / branch_q.log / branch_v.log are generated in logs/ successfully"
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
	if [[ $# -ne 2 ]]; then
		echo "Usage : bDiff <file> <#rev>"
	else
		diffFile=${1}
		curRev=${2}
		prevRev=`cat ${brqLog} | grep ${curRev} -A2 | tail -1 | awk '{print $1}' | sed 's/r//'`
		svn diff ${brUrl}/${diffFile} -r ${curRev}:${prevRev}
	fi
}

# diff two URL files (trunk & branch) and save the diff file
function tbDiff() 
{
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
		echo "'${tkLocalFile}' blame file is generated in blames/successfully."
		echo "'${brLocalFile}' blame file is generated in blames/successfully."
	fi
}

if [[ $0 == "./dryrun.sh" ]]; then
	mkdir logs diffs blames
	# get dryrun
	cd ${tkPath}
	echo "getting dryrun.log ..."
	getRevCopied && brRev=${?}
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
