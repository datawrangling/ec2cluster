#!/bin/bash
# ubuntu MPI cluster installs and config https://help.ubuntu.com/community/MpichCluster
# this script is kicked off as root within /home/elasticwulf on the master node

# TODO: check if any installs need to be modified for 64 bit vs. 32 bit amis
# information can be obtained by curl of instance metadata.

aws_access_key_id=$1
aws_secret_access_key=$2
admin_user=$3
admin_password=$4
rest_url=$5
job_id=$6

cat <<EOF >> /home/elasticwulf/cluster_config.yml
aws_access_key_id: $aws_access_key_id
aws_secret_access_key: $aws_secret_access_key
admin_user: $admin_user
admin_password: $admin_password
rest_url: $rest_url
job_id: $job_id
EOF

chown elasticwulf:elasticwulf /home/elasticwulf/config.yml

addgroup admin
adduser elasticwulf admin
echo '' >> /etc/sudoers
echo '# Members of the admin group may gain root ' >> /etc/sudoers
echo '%admin ALL=NOPASSWD:ALL' >> /etc/sudoers

# version control
apt-get -y install zip unzip rsync bzip2
apt-get -y install curl subversion mercurial git-core cvs
apt-get -y install s3cmd ec2-ami-tools

# MPI related
apt-get -y install build-essential
apt-get -y install libboost-serialization-dev
apt-get -y install libexpat1-dev
apt-get -y install libopenmpi1 openmpi-bin openmpi-common
apt-get -y install libopenmpi-dev

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


gem install right_http_connection --no-rdoc --no-ri
gem install right_aws --no-rdoc --no-ri
gem install activeresource --no-ri --no-rdoc

# R & octave installs
apt-get -y install r-base r-base-core
apt-get -y install r-base-dev r-base-html r-base-latex r-cran-date octave3.0
# basic HPC R packages, 
apt-get -y install r-cran-rmpi r-cran-snow

# see http://cran.r-project.org/web/views/HighPerformanceComputing.html
# http://cran.r-project.org/web/packages/Rmpi/index.html
# http://cran.r-project.org/web/packages/snow/index.html

cat <<EOF >> /home/elasticwulf/hello.c
#include <stdio.h>
#include <mpi.h>

int main(int argc, char *argv[]) {
  int numprocs, rank, namelen;
  char processor_name[MPI_MAX_PROCESSOR_NAME];

  MPI_Init(&argc, &argv);
  MPI_Comm_size(MPI_COMM_WORLD, &numprocs);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Get_processor_name(processor_name, &namelen);

  printf("Process %d on %s out of %d\n", rank, processor_name, numprocs);

  MPI_Finalize(); 
  }
EOF

chown elasticwulf:elasticwulf /home/elasticwulf/hello.c

# Quick test of MPI
su - elasticwulf -c "mpicc /home/elasticwulf/hello.c -o /home/elasticwulf/hello" 
### check number of processors available
# cat /proc/cpuinfo 
su - elasticwulf -c "mpirun --mca btl ^openib -np 2 /home/elasticwulf/hello"

# TODO: will we have a client gem???

# then we run a "GET" to get all the job properties for that id on the master node.
# we can fetch the indicated files from s3, (the buckets should be owned by the same AWS key)
# need to trigger /nextstep at start of job
# then run the mpi command / bash script indicated,
# finally, we send the output files up to the s3 bucket indicated
# when that is complete, we trigger nextstep again.

#  s3.put(bucket_name, 'S3keyname.forthisfile',  File.open('localfilename.dat'))



