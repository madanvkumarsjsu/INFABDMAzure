#!/bin/bash
#Script arguments
VMAdminUserName$1
HDIClusterName=$2
HDIClusterLoginUsername=$3
HDIClusterLoginPassword=$4
HDIClusterSSHHostname=$5
HDIClusterSSHUsername=$6
HDIClusterSSHPassword=$7
Clusterjobhistory=$8
Clusterjobhistorywebapp=$9
ClusterRMSaddress=$10
ClusterRMWaddress=$11
#Check
mkdir /home/$VMAdminUserName/logs
echo $VMAdminUserName $HDIClusterName $HDIClusterLoginUsername $HDIClusterLoginPassword $HDIClusterSSHHostname $HDIClusterSSHUsername $HDIClusterSSHPassword 
#whoami > /home/$VMAdminUserName/logs/user.log
#pwd > /home/$VMAdminUserName/logs/output.log

#RPM download
mkdir /home/$VMAdminUserName/infaRPMInstall
cd /home/$VMAdminUserName/infaRPMInstall
wget http://ispstorenp.blob.core.windows.net/bderpm/informatica_10.0.0-1.deb

#Ambari API calls to extract Head node and Data nodes
echo "Getting list of hosts from ambari"
hostsJson=$(curl -u $HDIClusterLoginUsername:$HDIClusterLoginPassword -X GET https://$HDIClusterName.azurehdinsight.net/api/v1/clusters/$HDIClusterName/hosts)
echo $hostsJson 

echo "Parsing list of hosts"
hosts=$(echo $hostsJson | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w 'host_name')
echo $hosts

echo "Extracting headnode0"
headnode0=$(echo $hosts | grep -Eo '\bhn0-([^[:space:]]*)\b') 
echo $headnode0
echo "Extracting headnode0 IP addresses"
headnode0ip=$(dig +short $headnode0) 
echo "headnode0 IP: $headnode0ip"

#Add a new line to the end of hosts file
echo "">>/etc/hosts
echo "Adding headnode IP addresses"
echo "$headnode0ip headnode0">>/etc/hosts

echo "Extracting workernode"
workernodes=$(echo $hosts | grep -Eo '\bwn([^[:space:]]*)\b') 
echo "Extracting workernodes IP addresses"
echo "workernodes : $workernodes" 
wnArr=$(echo $workernodes | tr "\n" "\n")
#tmpRemoteFolderName = rpmtemp
#filename = informatica_10.0.0-1.deb
sudo apt-get install sshpass
for workernode in $wnArr
do
    echo "[$workernode]" 
	workernodeip=$(dig +short $workernode)
	echo "workernodeip $workernodeip" 
	#create temp folder
	sudo sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$workernodeip "sudo mkdir ~/rpmtemp" 
	#Give permission to rpm folder
	sudo sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$workernodeip "sudo chmod 777 ~/rpmtemp"
	#SCP infa binaries
	sudo sshpass -p $HDIClusterSSHPassword scp informatica_10.0.0-1.deb $HDIClusterSSHUsername@$workernodeip:"~/rpmtemp/" 
	#extract the binaries
	sudo sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$workernodeip "sudo dpkg -i ~/rpmtemp/informatica_10.0.0-1.deb"
	#Clean the temp folder
	sudo sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$workernodeip "sudo rm -rf ~/rpmtemp"
done

#testpurpose of updating yarn site - Start
echo $Clusterjobhistory $Clusterjobhistorywebapp $ClusterRMSaddress $ClusterRMWaddress > /home/devuser/clusterdata.log
sudo dpkg -i informatica_10.0.0-1.deb
sed -i '/<configuration>/ a <property>\n<name>mapreduce.jobhistory.address</name>\n<value>'$Clusterjobhistory'</value>\n<description>MapReduce JobHistory Server IPC host:port</description>\n</property>' /opt/Informatica/services/shared/hadoop/hortonworks_2.2/conf/yarn-site.xml
sed -i '/<configuration>/ a <property>\n<name>mapreduce.jobhistory.webapp.address</name>\n<value>'$Clusterjobhistorywebapp'</value>\n<description>MapReduce JobHistory Server Web UI host:port</description>\n</property>' /opt/Informatica/services/shared/hadoop/hortonworks_2.2/conf/yarn-site.xml
sed -i '/<configuration>/ a <property>\n<name>yarn.resourcemanager.scheduler.address</name>\n<value>'$ClusterRMSaddress'</value>\n<description>CLASSPATH for YARN applications. A comma-separated list of CLASSPATH entries</description>\n</property>' /opt/Informatica/services/shared/hadoop/hortonworks_2.2/conf/yarn-site.xml
sed -i '/<configuration>/ a <property>\n<name>yarn.resourcemanager.webapp.address</name>\n<value>'$ClusterRMWaddress'</value>\n<description>CLASSPATH for YARN applications. A comma-separated list of CLASSPATH entries</description>\n</property>' /opt/Informatica/services/shared/hadoop/hortonworks_2.2/conf/yarn-site.xml
#testpurpose of updating yarn site - End
cd /home/$VMAdminUserName
rm -rf /home/$VMAdminUserName/infaRPMInstall
