#!/bin/bash

emailto="sysadmin@icontrol.com"
emailfrom="iCbackups@polaris.icontrol.com"
emailsubject="Backup Files Not Current !!!"

umask 700
rm -rf /tmp/check
mkdir /tmp/check

if [ $? -eq 1 ];then
    # can't create the safe directory. Exit
    echo "Error on safe dir creation"
    exit
fi


backupdirs=`ls /mnt/backup/ | awk '{print $NF}'`
logoldfiles="/tmp/check/oldfiles.log"

mounted=`df -k | grep "mnt/backup" | awk '{print $NF}'`
if [[ $mounted == '/mnt/backup' ]]; then
	echo "to:"$emailto > $logoldfiles ;
	echo "from:"$emailfrom >> $logoldfiles ;
	echo "subject:"$emailsubject >> $logoldfiles ;
	echo "" >> $logoldfiles;

	for chost in $backupdirs
	do
		if [ $chost != "archive" ]; then 
    			cd /mnt/backup/$chost/ ;
    			filelist=`ls | grep 'Mon.tgz\|Tue.tgz\|Wed.tgz\|Thu.tgz\|Fri.tgz\|Sat.tgz\|Sun.tgz' | grep -v ".md5"` ;
			for cfile in $filelist
    			do
				cfileMD5="${cfile}.md5"
				checkMD5=`md5sum -c  $cfileMD5 2> /dev/null | awk '{print $2}'`
				#echo -e `readlink -f $cfile`":"`md5sum -c  ${cfileMD5} 2> /dev/null | awk '{print $2}'` "\n\n"
				if [[ $checkMD5 != "OK" ]]; then
					if [[ -z $checkMD5 ]]; then
						echo "" >> $logoldfiles
						echo "`readlink -f $cfile` md5 missing" >> $logoldfiles
					fi
					if [[ $checkMD5 == "FAILED" ]]; then
						echo "" >> $logoldfiles
						echo "`readlink -f $cfile` bad md5 checksum" >> $logoldfiles
					fi
				fi 

				oldfile=`find ./$cfile -mtime +6` ;
        			if [ $oldfile ]; then
					cdate=`date +"%e"`
					ncdate=`date +"%w"`
                			fdate=`ls -l $oldfile | awk '{print $7}'`

						dayofweek=`echo $oldfile | tail -c8 | cut -d. -f1`
						if [ $dayofweek == "Sun" ] ; then
							weeknumday=0;		
						elif [ $dayofweek == "Mon" ] ; then
							weeknumday=1; 
						elif [ $dayofweek == "Tue" ] ; then
							weeknumday=2; 
						elif [ $dayofweek == "Wed" ] ; then
							weeknumday=3; 
						elif [ $dayofweek == "Thu" ] ; then
							weeknumday=4; 
						elif [ $dayofweek == "Fri" ] ; then
							weeknumday=5; 
						elif [ $dayofweek == "Sat" ] ; then
							weeknumday=6; 
						fi
			
						if [ $weeknumday == `date +"%w"` ] ; then
							expected=`date +"%b %e"`;
						else
							if [ $weeknumday == 0 ] ; then
								expected=`date --date="Last Sunday" +"%b %e"`
							elif [ $weeknumday == 1 ] ; then
								expected=`date --date="Last Monday" +"%b %e"`
							elif [ $weeknumday == 2 ] ; then
                                        			expected=`date --date="Last Tuesday" +"%b %e"`
							elif [ $weeknumday == 3 ] ; then
                                        			expected=`date --date="Last Wednesday" +"%b %e"`
							elif [ $weeknumday == 4 ] ; then
                                        			expected=`date --date="Last Thursday" +"%b %e"`
							elif [ $weeknumday == 5 ] ; then
                                        			expected=`date --date="Last Friday" +"%b %e"`
							elif [ $weeknumday == 6 ] ; then
                                        			expected=`date --date="Last Saturday" +"%b %e"`
							fi
						fi
				echo "" >> $logoldfiles
				echo `pwd`"/"`echo $oldfile | cut -d"/" -f 2` "      Expected: "$expected  "      Actual: "`ls -l $oldfile | awk '{print $6,$7}'` >> $logoldfiles
				fi
    			done
    		fi
	done
	if [ -z "`tail -n1 "$logoldfiles"`" ] ; then
		rm -f $oldlogfiles
	else
		/usr/sbin/sendmail -t < $logoldfiles
		rm -f $logoldfiles
	fi
else
	emailto="sysadmin@icontrol.com"
	emailfrom="iCBackups@polaris.icontrol.com"
	emailsubject="Storform (/mnt/backup) Not Mounted !!!"
	tmpfile="/tmp/check/storform"
 	
	echo "to:"$emailto > $tmpfile ;
        echo "from:"$emailfrom >> $tmpfile;
        echo "subject:"$emailsubject >> $tmpfile;
        echo "" >> $tmpfile;
        echo "Storform (/mnt/backup) not mounted.  Please fix immediately!!!!" >> $tmpfile;
        
	/usr/sbin/sendmail -t < $tmpfile;
        
	rm -f $tmpfile
fi
