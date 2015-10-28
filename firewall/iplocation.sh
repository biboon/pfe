#!/bin/bash

while read line
do
        [ -z "$line" ] && continue
        if [ ! ${line:0:1} == "#" ]
        then
                curl ipinfo.io/$line
        fi
done < $1
