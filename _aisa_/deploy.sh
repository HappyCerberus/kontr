# this file is specific to aisa.fi.muni.cz

files="config.ini Helpers.pm StudentInfo.pm UserInfo.pm Types.pm FISubmission.pm Submission.pm FIHomework.pm Homework.pm TimeLock.pm Lock.pm neodevzdavam odevzdavam"
pubpth=/home/xtoth1/kontrPublic/
srcpth=/home/xtoth1/kontrNG/

for f in $files; do
	if [ -r $pubpth/$f ]; then
		if [ `stat -c%i $pubpth/$f` == `stat -c%i $srcpth/$f` ]; then
			echo "\"$f\" already correctly linked";
			continue;
		fi

		echo "\"$f\" incorectly linked, cleaning up"
		rm -f $pubpth/$f;
	fi

	echo "linking $f"
	ln $srcpth/$f $pubpth/$f;
done

mkdir -p $pubpth/otevrene
mkdir -p $pubpth/otevrene/pripravene
mkdir -p $pubpth/odevzdani
mkdir -p $pubpth/opravene
