#!/bin/bash

# this file is specific to aisa.fi.muni.cz

if [ -r /home/xtoth1/kontrNG/maintenance ]; then exit 0; fi

exec 1>>/home/xtoth1/kontrNG/_logs_/starter.sh 2>&1

date

# try to lock the master lock, bail after 5*8 seconds
lockfile -r5 /home/xtoth1/kontrNG/master.lock
if [ $? -ne 0 ]; then exit 0; fi

# update kontr
pushd /home/xtoth1/kontrNG
timeout 120 git pull
popd

#Redownload tests if needed
if [ ! -d /home/xtoth1/kontrNG/_tests_ ]; then
    pushd /home/xtoth1/kontrNG
    git clone --depth=1 git@github.com:xbrukner/kontr_tests.git _tests_
    popd
fi

#Remove wrong tests if needed
if [ -d /home/xtoth1/kontrNG/tests2 ]; then
    rm -rf /home/xtoth1/kontrNG/tests2
fi

# update tests
pushd /home/xtoth1/kontrNG/_tests_
timeout 120 git pull
popd

. /packages/run/modules-2.0/init/bash
module add gcc-4.8.2
module add allegro-5.1
module add curl-7.18.2

cd /home/xtoth1/kontrNG
/packages/run/links/bin/perl /home/xtoth1/kontrNG/starter.pl &>>/home/xtoth1/kontrNG/_logs_/starter.pl

rm -f /home/xtoth1/kontrNG/master.lock
