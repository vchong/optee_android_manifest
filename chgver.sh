#!/bin/bash

if [ "$#" -ne 2 ]; then
	echo "usage: ./chgver.sh 3\.15\.0 3\.16\.0"
	exit 0
fi

find . -type f -exec sed -i 's/'$1'/'$2'/g' {} \;
#find . -type f -name foo -exec sed -i 's/'$1'/'$2'/g' {} \;
