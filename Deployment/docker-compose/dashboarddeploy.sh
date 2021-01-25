#!bin/bash

# Set values for the below 
export PdrHostIP=
export PdrHostPort=
export VolumeMountPath=

if [[ -d "$VolumeMountPath" ]]; then
  echo "Volume mount path exists... : ${VolumeMountPath}"
else
  echo "Volume mount path does not exist. Aborting... : ${VolumeMountPath}"
  exit 1
fi

#Copy volume content to volume mount path.
cp -a ../preconfiguration/. ${VolumeMountPath}/dashboardvolumes/
chmod -R a+w ${VolumeMountPath}/dashboardvolumes/

#Do not modify the section below
export OfflineDeploymentMode=false

if [[ $OfflineDeploymentMode == true ]]
then
	set -- "$@" "--offline"
fi

#Enabling firewall for communication between containers
firewall-cmd --zone=public --add-port=9011/tcp --permanent
firewall-cmd --zone=public --add-port=9012/tcp --permanent
firewall-cmd --zone=public --add-port=9013/tcp --permanent
firewall-cmd --zone=public --add-port=9014/tcp --permanent
firewall-cmd --zone=public --add-port=9015/tcp --permanent
firewall-cmd --zone=public --add-port=9016/tcp --permanent
firewall-cmd --zone=public --add-port=9017/tcp --permanent
firewall-cmd --zone=public --add-port=9018/tcp --permanent
firewall-cmd --zone=public --add-port=9019/tcp --permanent
firewall-cmd --reload


#Ask for user input if the -c flag is not passed
if [[ $* == *--offline* ]]
then
    echo "Offline mode: Docker Images will be retrieved from the local cache"
    export ImageRepo=""
else
    echo "Online mode: Docker Images will be pulled from the PDR"
    export ImageRepo=$PdrHostIP:$PdrHostPort/fdm/
	
	if [[ $* != *-c* ]]
	then
		echo -n "PDR login username: "
		read PdrUsername

		echo -n "PDR login password: "
		read -s PdrPassword
		echo
	else
		if [ $# -ge 6 ]
		then
			while getopts "u:p:c:" opt; do
					case $opt in
							u) PdrUsername="$OPTARG";;
							p) PdrPassword="$OPTARG";;
							c) CICD="$OPTARG";;
							\?) exit ;;
					esac
			done
			    else
			echo "This script in CICD mode requires arguments in -u <PDR_username> -p <PDR_password> -c CICD format"
			exit
		fi
	fi
	
	echo "Logging as $PdrUsername to PDR for Images"
	if echo $PdrPassword | docker login $PdrHostIP:$PdrHostPort --username $PdrUsername --password-stdin
	then
		echo "User Logged In to PDR"
	else
		echo "Unable to proceed with the deployment, login to PDR failed!"
		exit 1
	fi
fi

if [[ $* != *-c* ]]
then
    rm -rf ../.secrets
    mkdir ../.secrets

    echo -n "Database username: "
    read DbUserId

	if [ ${#DbUserId} -lt 1 ]
	then
	    echo "DB userId should not be empty."
		exit 1
	fi
    echo -n $DbUserId > ../.secrets/dbuser

    echo -n "Database password: "
    read -s DbKey
	
	if [ ${#DbKey} -lt 5 ]
	then  
	    echo "DB password should not be empty, atleast min. 5 charecter required."
		exit 1
	fi

    echo -n $DbKey > ../.secrets/dbkey
    echo

else
      DbUserId=$(< ../.secrets/dbuser)
      DbKey=$(< ../.secrets/dbkey)
fi


export DbUser=$DbUserId	
export DbPwd=$DbKey	

echo "bringing down the docker-compose"
docker-compose down

if [[ $* == *--offline* ]]
then
	echo "Loading Docker Images from Offline Package"
	for file in ../docker-images/*.tar
		do
			echo $file
				docker load < $file 
		done
fi

echo "Deploying HealthSuite Monitoring Tool"
docker-compose up --build -d






