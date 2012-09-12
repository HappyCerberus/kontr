#!/bin/bash

# this file is specific to aisa.fi.muni.cz

if [ -r /home/xtoth1/kontrNG/maintenance ]; then exit 0; fi

exec 1>>/home/xtoth1/kontrNG/_logs_/starter.sh 2>&1

# try to lock the master lock, bail after 5*8 seconds
lockfile -r5 /home/xtoth1/kontrNG/master.lock
if [ $? -ne 0 ]; then exit 0; fi

# update kontr
pushd /home/xtoth1/kontrNG
git pull
popd

# update tests
pushd /home/xtoth1/kontrNG/_tests_
git pull
popd

. /packages/run/modules-2.0/init/bash
module add gcc-4.5.3
module add allegro-5.1

cd /home/xtoth1/kontrNG
/packages/run/links/bin/perl /home/xtoth1/kontrNG/starter.pl &>>/home/xtoth1/kontrNG/_logs_/starter.pl

rm -f /home/xtoth1/kontrNG/master.lock
