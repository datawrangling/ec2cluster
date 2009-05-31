#!/bin/bash
# ubuntu MPI cluster installs
# this script is kicked off as root within /home/elasticwulf on all nodes 

# TODO: check if any installs need to be modified for 64 bit vs. 32 bit amis
# information can be obtained by curl of instance metadata.

# TODO: add option for alternate MPI library (lam, mpich2, etc)

aws_access_key_id=$1
aws_secret_access_key=$2
admin_user=$3
admin_password=$4
rest_url=$5
job_id=$6
user_packages="$7"

cat <<EOF >> /home/elasticwulf/cluster_config.yml
aws_access_key_id: $aws_access_key_id
aws_secret_access_key: $aws_secret_access_key
admin_user: $admin_user
admin_password: $admin_password
rest_url: $rest_url
job_id: $job_id
user_packages: $user_packages
EOF

chown elasticwulf:elasticwulf /home/elasticwulf/cluster_config.yml

addgroup admin
adduser elasticwulf admin
echo '' >> /etc/sudoers
echo '# Members of the admin group may gain root ' >> /etc/sudoers
echo '%admin ALL=NOPASSWD:ALL' >> /etc/sudoers

# install basic unix tools
apt-get -y install gawk curl
apt-get -y install zip unzip rsync bzip2

# version control
apt-get -y install git-core
apt-get -y install subversion mercurial cvs

# Amazon related tools
apt-get -y install s3cmd ec2-ami-tools 

# MPI related
apt-get -y install build-essential
apt-get -y install libboost-serialization-dev
apt-get -y install libexpat1-dev
apt-get -y install libopenmpi1 openmpi-bin openmpi-common libopenmpi-dev

# ruby and ruby gems...
apt-get -y install ruby-full build-essential
wget http://rubyforge.org/frs/download.php/45905/rubygems-1.3.1.tgz
tar xzvf rubygems-1.3.1.tgz
cd rubygems-1.3.1
sudo ruby setup.rb
sudo ln -s /usr/bin/gem1.8 /usr/bin/gem
sudo gem update --system
cd ../
rm rubygems-1.3.1.tgz
rm -R rubygems-1.3.1

# Gems needed for command runner
gem install right_http_connection --no-rdoc --no-ri
gem install right_aws --no-rdoc --no-ri
gem install activeresource --no-ri --no-rdoc

# R & octave installs
apt-get -y install r-base r-base-core
apt-get -y install r-base-dev r-base-html r-base-latex r-cran-date octave3.0

# basic HPC R packages, 
# see http://cran.r-project.org/web/views/HighPerformanceComputing.html
# http://cran.r-project.org/web/packages/Rmpi/index.html
# http://cran.r-project.org/web/packages/snow/index.html
apt-get -y install r-cran-rmpi r-cran-snow

# # python installs
# apt-get -y install python-boto python-imaging python-dateutil 
# # python numerical computing:
# apt-get -y install python-setuptools python-docutils 
# apt-get -y install python-support python-distutils-extra 
# apt-get -y install python-dev python-numpy python-numpy-ext python-scipy cython 


# install any user defined packages
if [ "$user_packages" != "" ]; then
  apt-get -y install $user_packages
fi

INSTANCE_ID=`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`
# Get node id for instance
NODE_ID=`curl -u $admin_user:$admin_password -k ${rest_url}jobs/${job_id}/search?query=${INSTANCE_ID}`

# configure NFS on master node and set up keys
# master security group has the format: 8-elasticwulf-master-052609-0823PM 
SECURITY_GROUPS=`wget -q -O - http://169.254.169.254/latest/meta-data/security-groups`

# Job state is "waiting_for_nodes"
# Send REST PUT to node url, signaling that node is ready 
curl -H "Content-Type: application/json" -H "Accept: application/json" -X PUT -d "{"node": {"is_configured":"true"}}" -u $admin_user:$admin_password -k ${rest_url}jobs/${job_id}/nodes/${NODE_ID}

if [[ "$SECURITY_GROUPS" =~ "master" ]]
then
  echo "Node is master, installing nfs server"
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
  echo 'node is a worker, skipping NFS export step'
fi


if [[ "$SECURITY_GROUPS" =~ "master" ]]
then
  # have to wait in loop for all nodes to start
  while [[ "$JOB_STATE" != "exporting_master_nfs"  ]]
  do
    sleep 5
    JOB_STATE=`curl -u $admin_user:$admin_password -k ${rest_url}jobs/${job_id}/state`
  done
  echo "Master node NFS export complete"
  # Send REST PUT to node url, signaling that NFS export is ready on MASTER node..
  curl -H "Content-Type: application/json" -H "Accept: application/json" -X PUT -d "{"node": {"nfs_mounted":"true"}}" -u $admin_user:$admin_password -k ${rest_url}jobs/${job_id}/nodes/${NODE_ID}
  # this needs to trigger a state transition, from exporting_master_nfs -> mounting_nfs
else
  echo 'node is a worker, waiting for master NFS export to complete'
  while [[ "$JOB_STATE" != "mounting_nfs" ]]
  do
    sleep 5
    JOB_STATE=`curl -u $admin_user:$admin_password -k ${rest_url}jobs/${job_id}/state`
  done  
fi

### Set up hosts file on each node. hostsfile will only be ready after all child nodes start booting.
chmod go-w /mnt/elasticwulf
curl -u $admin_user:$admin_password -k ${rest_url}jobs/${job_id}/hosts >> /etc/hosts
sed -i -e 's/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/g' /etc/ssh/ssh_config
/etc/init.d/ssh restart

MASTER_HOSTNAME=`curl -u $admin_user:$admin_password -k ${rest_url}jobs/${job_id}/masterhostname`

# mount NFS home dir on worker nodes 
if [[ "$SECURITY_GROUPS" =~ "master" ]]
then  
  echo "node is the master node, skipping NFS mount, waiting for worker nodes to mount home dir"
  # fetch openmpi_hostfile from jobs url
  su - elasticwulf -c "curl -u $admin_user:$admin_password -k ${rest_url}jobs/${job_id}/openmpi_hostfile > openmpi_hostfile"

  WORKER_NODES=`cat openmpi_hostfile | wc -l | cut --delimiter=' ' -f 1`
  MOUNTED_NODES=`grep 'authenticated mount request' /var/log/syslog | wc -l`
  while [ $MOUNTED_NODES -lt $WORKER_NODES ]
  do
    echo "Waiting for worker nfs mounts..."  
    sleep 5
    MOUNTED_NODES=`grep 'authenticated mount request' /var/log/syslog | wc -l`
  done  
  echo "All workers have mounted NFS home directory, cluster is ready for MPI jobs"
  
  # Quick test of local openmpi
  su - elasticwulf -c "mpicc /home/elasticwulf/elasticwulf-service/lib/examples/hello.c -o /home/elasticwulf/hello" 
  su - elasticwulf -c "mpirun -np 2 /home/elasticwulf/hello > local_mpi_smoketest.txt"  
  # Get total number of cpus in cluster from REST action
  CPU_COUNT=`curl -u $admin_user:$admin_password -k ${rest_url}jobs/${job_id}/cpucount`
  # Quick smoke test of multinode openmpi run, 
  su - elasticwulf -c "mpirun -np $CPU_COUNT --hostfile /home/elasticwulf/openmpi_hostfile /home/elasticwulf/hello > cluster_mpi_smoketest.txt"

  # kick off ruby command_runner.rb script (only on master node)
  su - elasticwulf -c "ruby /home/elasticwulf/elasticwulf-service/lib/command_runner.rb $CPU_COUNT"  
  
else  
  echo "Node is worker, mounting master NFS"
  apt-get -y install portmap nfs-common
  mount ${MASTER_HOSTNAME}:/mnt/elasticwulf /mnt/elasticwulf
  # Send REST PUT to node url, signaling that NFS is ready on node..
  curl -H "Content-Type: application/json" -H "Accept: application/json" -X PUT -d "{"node": {"nfs_mounted":"true"}}" -u $admin_user:$admin_password -k ${rest_url}jobs/${job_id}/nodes/${NODE_ID}  
fi