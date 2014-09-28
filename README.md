svnmerge
========
some svn-merge tools

steps :
1)  mkdir ~/Merge/
2)  cp dryrun.sh conflict.sh ~/Merge
3)  pull trunk and branch to ~/Merge
4)* ./dryrun.sh (generate dryrun.log)
5)* ./conflict.sh (generate conflict diff files)
6) 	mkdir diffs; mv src* ./diffs

Just use hdiff/hblame : 
1) source conflict.sh (expose hdiff)
2) hdiff/blame <conflict file> (generate the conflict diff/blame file) 
