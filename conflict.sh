#!/bin/bash

# get conflict files from dryrun.log and diff & save them 

tkUrl="http://localhost/svn/trunk"
brUrl="http://localhost/svn/branches/br"
dryrunLog="/home/young/Merge/dryrun.log"

# diff two URL files (trunk & branch) and save the diff file
function hdiff() 
{
	if [[ $# -ne 1 ]]; then
		echo "Usage : $0 <file>"
	else
		diffFile=${1}
		tkFile=${tkUrl}/${diffFile}
		brFile=${brUrl}/${diffFile}
		# replace '/' with '_' in the file name
		localFile=${1//\//_}
		svn diff ${tkFile} ${brFile} > ${localFile}
		echo "'${localFile}' diff file is generated successfully."
	fi
}

# blame two URL blame (trunk & branch) and save the blame file
function hblame()
{
	if [[ $# -ne 1 ]]; then
		echo "Usage : $0 <file>"
	else
		blameFile=${1}
		tkFile=${tkUrl}/${blameFile}
		brFile=${brUrl}/${blameFile}
		# replace '/' with '_' in the file name and add prefix 'b-tk' or 'b-br' 
		tkLocalFile="b-tk-${1//\//_}"
		brLocalFile="b-br-${1//\//_}"
		svn blame ${tkFile} > ${tkLocalFile}
		svn blame ${brFile} > ${brLocalFile}
		echo "'${tkLocalFile}' blame file is generated successfully."
		echo "'${brLocalFile}' blame file is generated successfully."
	fi
}

if [[ $0 == "./conflict.sh" ]]; then
	# get conflict files from dryrun.log
	cRawFiles=`sed -n '/^C/p' ${dryrunLog}`
	cFiles=`echo "${cRawFiles}" | awk '{print $2}'` 

	# diff conflict file and then save diff file 
	i=0
	for cFile in ${cFiles}; do
		let i++	
		hdiff ${cFile}
	done
	echo -e "\n${i} files"
fi
