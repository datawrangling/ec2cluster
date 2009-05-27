#!/bin/bash
# ubuntu MPI cluster config.  This script is kicked off as root within 
# /home/elasticwulf on all nodes when /clusterstatus is reported as 'configuring_cluster'

aws_access_key_id=$1
aws_secret_access_key=$2
admin_user=$3
admin_password=$4
rest_url=$5
job_id=$6


### Set up hosts file. hostsfile will only be ready after all child nodes start booting.

chmod go-w /mnt/elasticwulf
curl -u $admin_user:$admin_password -k ${rest_url}jobs/${job_id}/hosts >> /etc/hosts
sed -i -e 's/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/g' /etc/ssh/ssh_config
/etc/init.d/ssh restart

# configure NFS on master or worker nodes (from Hadoop config scripts)
# master security group has the format: 8-elasticwulf-master-052609-0823PM 
SECURITY_GROUPS=`wget -q -O - http://169.254.169.254/latest/meta-data/security-groups`
IS_MASTER=`echo $SECURITY_GROUPS | gawk '{ a = match ($0, "-master\\>"); if (a) print "true"; else print "false"; }'`
if $IS_MASTER ; then
  sudo apt-get -y install nfs-kernel-server
  echo '/mnt/elasticwulf *(rw,sync)' >> /etc/exports
  /etc/init.d/nfs-kernel-server restart

  ############ ON MASTER NODE AS ELASTICWULF USER ############
  #As the home directory of elasticwulf in all nodes is the same (/home/elasticwulf) ,
  #there is no need to run these commands on all nodes.
  #First we generate DSA key for elasticwulf (leaves passphrase empty):
  su - elasticwulf -c "ssh-keygen -b 1024 -N '' -f ~/.ssh/id_dsa -t dsa -q"

  #Next we add this key to authorized keys on master node:
  su - elasticwulf -c "cat ~/.ssh/id_dsa.pub >> ~/.ssh/authorized_keys"
  su - elasticwulf -c "chmod 700 ~/.ssh"
  su - elasticwulf -c "chmod 600 ~/.ssh/*"

else
  apt-get -y install portmap nfs-common
  mount master:/mnt/elasticwulf /mnt/elasticwulf
fi

# TODO: fetch openmpi_hostfile from jobs url...


