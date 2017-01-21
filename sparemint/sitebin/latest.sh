#!/bin/sh

outfile=/home/frank/sparemint/html/lastnews.html

serverpath=http://sparemint.atariforge.org/sparemint/html/packages
path=/home/frank/sparemint/RPMS/m68kmint

# head
echo "<!-- begin sparemint -->" > ${outfile}

for i in `ls -t ${path} | head -n 30`;
do
	info=`rpm -qip ${path}/$i`
	
	name=`echo "${info}" | grep "Name"`
	name=`echo "${name}" | sed "s/Name *: \([^ ]*\).*/\1/g"`
	
	summary=`echo "${info}" | grep "Summary"`
	summary=`echo "${summary}" | sed "s/Summary *: //g"`
	
	vname=`echo "${i}" | sed "s/\(.*\)\.m68kmint\.rpm/\1/g"`
	
	echo "+++ <a href="${serverpath}/${name}.html" target="_blank">${vname}</a> ${summary} " >> ${outfile} 
	
	echo "${vname}"
done

# finish
echo "<!-- end sparemint -->" >> ${outfile}

