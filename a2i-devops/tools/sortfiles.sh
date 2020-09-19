#!/bin/bash

filelist=`find ./ -type f | grep '.txt'`

#echo "$filelist

for word in $filelist; do
  #statements
  echo  "$word"
  filname=`echo $word | rev | cut -d '/' -f1 | rev`
  directory=`echo $word | rev | cut -d '/' -f2- | rev`
  echo "filename is $filname and directory is $directory"
done
