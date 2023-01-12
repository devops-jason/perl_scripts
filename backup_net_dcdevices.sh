#!/bin/bash

EmailAddress="sysadmin@icontrol.com"
BACKUP_LOC="/data/www/network_dc_configs/configs/"
WEB_LOC="/data/www/network_dc_configs/web/"
DATE=`date -d "Yesterday" +"%m-%d-%Y_%H"`
SIZE="2000"
ERROR="N"
PIX="pix-config"
SWITCH="switch-config"
CSS="css-config"
DEVICES="pix css switch"
ADMIN="admin1 controlmon1"
CMD_LOC="/usr/local/sbin/"
REMOTE_DUMP="/data/network_configs/"
REMOTE_WEBCMD="nipper "

for cAdmin in $ADMIN
do	
	echo "Grabbing the list of network devices for ${cAdmin}"
	perl -e "print '-' x 50"
	LOGIN=""

	if [ -d "${BACKUP_LOC}${cAdmin}/current" ]; then
		#Do Nothing
		echo ""
	else
		echo ""
       		echo "Creating directory ${BACKUP_LOC}${cAdmin}/current"
        	mkdir -pv ${BACKUP_LOC}${cAdmin}/current
		echo ""
	fi
	
        if [ -d "${BACKUP_LOC}${cAdmin}/previous" ]; then
                #Do Nothing
                echo ""
        else
		echo ""
                echo "Creating directory ${BACKUP_LOC}${cAdmin}/previous"
                mkdir -pv ${BACKUP_LOC}${cAdmin}/previous
		echo ""
        fi
	if [ -d "${BACKUP_LOC}${cAdmin}/archive" ]; then
                #Do Nothing
                echo ""
        else
		echo ""
                echo "Creating directory ${BACKUP_LOC}${cAdmin}/archive"
                mkdir -pv ${BACKUP_LOC}${cAdmin}/archive
        	echo ""
	fi
	
	#########################################
	# PIX
	#########################################
	echo "PIX List (${cAdmin}):"
	LIST=`ssh ${LOGIN}${cAdmin} "cat ${CMD_LOC}${PIX}.list" | cut -d"|" -f 1 | grep -v "^$"`

	echo $LIST | sed -e "s/ /\n/g"
	echo ""
	echo "Sending PIX configurations to ${cAdmin}"
	EXECUTE_CMD=`ssh ${LOGIN}${cAdmin} "${CMD_LOC}${PIX}.pl"`
	$EXECUTE_CMD
	echo "Done."
	echo ""

	##########################################
	# CSS
	##########################################
	echo "CSS List (${cAdmin}):"
        CLIST=`ssh ${LOGIN}${cAdmin} "cat ${CMD_LOC}${CSS}.list" | cut -d"|" -f 1 | grep -v "^$"`
	
	echo $CLIST | sed -e "s/ /\n/g"
        echo ""
        echo "Sending CSS configurations to ${cAdmin}"
        EXECUTE_CMD=`ssh ${LOGIN}${cAdmin} "${CMD_LOC}${CSS}.pl"`
        $EXECUTE_CMD
        echo "Done."
        echo ""

	##########################################
        # SWITCH
        ##########################################
        echo "SWITCH List (${cAdmin}):"
        SLIST=`ssh ${LOGIN}${cAdmin} "cat ${CMD_LOC}${SWITCH}.list" | cut -d"|" -f 1 | grep -v "^$"`

        echo $SLIST | sed -e "s/ /\n/g"
        echo ""
        echo "Sending SWITCH configurations to ${cAdmin}"
        EXECUTE_CMD=`ssh ${LOGIN}${cAdmin} "${CMD_LOC}${SWITCH}.pl"`
        $EXECUTE_CMD
        echo "Done."
        echo ""

	###########################################

	
	perl -e "print '#' x 50" ; echo ""
	LIST="${LIST} ${CLIST} ${SLIST}"
	
	for cFile in $LIST
	do
		if [ `echo ${cFile} | cut -d "-" -f 2` == "pix" ]; then
                        DEVICES="pix"
                else
                        if [ `echo ${cFile} | cut -d "-" -f 2` == "css" ]; then   
                                DEVICES="css"
                        else
                                if [ `echo ${cFile} | cut -d "-" -f 2` == "sw48" ]; then
                                        DEVICES="switch"
                                else
                                        if [ `echo ${cFile} | cut -d "-" -f 2` == "sw24" ]; then
                                                DEVICES="switch"
                                        fi
                                fi
                        fi
                fi
		OLD_FILE="${BACKUP_LOC}${cAdmin}/previous/${cFile}"
		if [ -f "${BACKUP_LOC}${cAdmin}/current/${cFile}" ]; then
			echo "Moving current file ${cFile} to previous"	
			mv -v ${BACKUP_LOC}${cAdmin}/current/${cFile} ${OLD_FILE}
			NOPREV="N"
		else
			NOPREV="Y"
		fi
		
		echo "Getting Current File"
		scp ${LOGIN}${cAdmin}:${REMOTE_DUMP}${DEVICES}/current/${cFile} ${BACKUP_LOC}${cAdmin}/current/
		
		echo ""
		
		if [ ${NOPREV} == "Y" ]; then
			#Do Nothing
			echo "No Previous Configuration"
			perl -e "print '#' x 50" ; echo ""
		else
			echo "Checking for differences:"
        		echo "-------------------------"
        		diff ${BACKUP_LOC}${cAdmin}/current/${cFile} ${OLD_FILE}
        		echo "-------------------------"
			
			#echo "Compressing ${OLD_FILE}..."
			#gzip "$OLD_FILE"
			#echo "Done."
	
			FILE_SIZE=`ls -l ${BACKUP_LOC}${cAdmin}/current/${cFile} | awk '{print $5}'`
        		if [ ${FILE_SIZE} -lt ${SIZE} ] ; then
               			echo "*******"
                		echo "*ERROR* ${cFile} file size is less than ${SIZE}"
               	 		echo "*******"
        	        	ERROR="Y"
	       		fi

			perl -e "print '#' x 50" ; echo ""
			
			if [ ${ERROR} == "Y" ]; then
				echo "*ERROR* file size is less than ${SIZE}, check the cron backup email for more info" | /bin/mail -s "DataCenter Net Config Error" $EmailAddress
			fi
		fi

	done 
	
	echo "Verifying directory is not empty"
	
	cd ${BACKUP_LOC}${cAdmin}/previous/
	if [ `ls -la | wc -l` -gt 4 ]; then
		echo "Passed."
		echo ""
		echo "Tarring ${BACKUP_LOC}${cAdmin}/previous/"
		tar --remove-files -cvzf  ../archive/configs_${cAdmin}_${DATE}.tar.gz ${LIST}
		echo "Done."
		echo "" 
		echo "Final Tar:"
		echo "----------"
		ls -l ../archive/configs_${cAdmin}_${DATE}.tar.gz
		echo ""; echo ""; echo "";
	else
		echo "Failed. The directory is to empty"
	fi

		
done



