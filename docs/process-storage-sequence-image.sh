#!/bin/bash

background='#fdefef'


scale=0.66

if [ -z $1 ] ; then
   echo Usage: $0 source-png
   exit 1
fi

source=$1
destination=../public/`basename $source`

echo $destination

if [ ! -f $source ] ; then
   echo "Source image $source doesnt exist"
   exit 1
fi

# for when we're using a background of white, with border:

# pngtopnm $source | pnmscale $scale | pnmcrop | pnmmargin -white 20 | pnmmargin -black 2 | pnmquant 16 | pnmtopng > $destination

# when we're trying to blend in

pngtopnm $source | pnmscale $scale | pnmcrop | pnmmargin -color "$background" 2 | pnmtopng -transparent "$background" > $destination
