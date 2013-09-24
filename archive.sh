#!/bin/bash

exec 1>>/home/xtoth1/kontrNG/_logs_/archive.sh 2>&1

date

DAYS=30
CONFIG="config.ini"

#MINUTES=$(($DAYS * 1440))
#TMPDIR=`grep "stage_path" $CONFIG | sed -e 's/^.*=//'`

#find $TMPDIR -mindepth 3 -maxdepth 3 -type d -mmin +$MINUTES -execdir sh -c 'tar -cjf $(basename $1).tar.bz2 `pwd`/$(basename $1) && rm -rf $1' _ {} \;
