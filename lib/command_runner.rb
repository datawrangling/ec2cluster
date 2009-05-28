#!/usr/bin/env ruby 

require 'rubygems'
require 'activeresource'
require 'right_aws'
require 'net/http'

CLUSTER_CONFIG = YAML.load_file("/home/elasticwulf/cluster_config.yml")
puts CLUSTER_CONFIG['job_id']

class Job < ActiveResource::Base
  self.site = CLUSTER_CONFIG['rest_url']
  self.user = CLUSTER_CONFIG['admin_user']
  self.password = CLUSTER_CONFIG['admin_password']
end

#############################

# look at instance metadata to determine if the node is a master or a slave
security_group_url = 'http://169.254.169.254/latest/meta-data/security-groups'
security_groups = Net::HTTP.get_response(URI.parse(security_group_url)).body

puts security_groups
is_master = security_groups.include? "master"
puts is_master

#    node_type()
#    fetch_job_attributes()
#    
# # if it is a slave, we do configure_worker_node() then exit...
#    configure_worker_node()
#    hit the REST url for this job_id, use GET on custom action to find node id which matches my instance id.
#    with that node id in hand, when I'm done configuring myself, I ping the REST service custom action to update
#    is_configured to true.


#   download_inputs()
#   run_command()
#   upload_outputs()
# # wrap everything in a try/rescue block which triggers 'error'


# Get Job attributes (input file names etc...)


job = Job.find(CLUSTER_CONFIG["job_id"].to_i)
puts job.master_instance_id
puts job.state


############################
# Fetch files from s3 to local working directory
s3 = RightAws::S3Interface.new(CLUSTER_CONFIG['aws_access_key_id'],
            CLUSTER_CONFIG['aws_secret_access_key'], {:multi_thread => true})
   
# TODO need to split supplied input by spaces, loop over inputs and fetch from s3.
# will assume a prefix of s3://
   
   
# fetch http://datawrangling.s3.amazonaws.com/colbert_2.gif   
foo = File.new('./colbert_2.gif', File::CREAT|File::RDWR) 
rhdr = s3.get('datawrangling', 'colbert_2.gif') do |chunk| foo.write(chunk) end
foo.close   

############################

# run job command and wait for completion, periodically updating progress

# popen4??

# PUT an update by invoking the 'nextstep' REST method, i.e. PUT /jobs/27/nextstep
# job.put(:nextstep)
# puts "Running /nextstep"
puts job.state

puts job.progress
# # PUT an update by invoking the 'updateprogress' REST method, i.e. PUT /jobs/28/updateprogress.xml?progress='downloading files'
job.put(:updateprogress, :progress => 'uploading')
job = Job.find(CLUSTER_CONFIG["job_id"].to_i)
puts job.progress


############################

# Upload job output files to S3

# here I use the datawrangling bucket
s3.put('datawrangling', 'cluster_mpi_smoketest.txt',  File.open('/home/elasticwulf/cluster_mpi_smoketest.txt'))

# right now we parse space delimited list of output files (assuming they are created in working directory)
# better convention might be to accept a pattern, i.e. foo*, which will grab all files matching that pattern.
# we can do an ls on that pattern and then iterate over the results.

# Convention may need to be for command to write all files to a directory (relative to /home/elasticwulf): /home/elasticwulf/searchoutput

#############################

# In Case of error, stop job and ping server with error message

# # PUT an update by invoking the 'error' REST method, i.e. PUT /jobs/28/error.xml?error_message='My nasty error message'.
# 
# puts "triggering error..."
# job.put(:error, :error_message => 'some horrible error message')
job = Job.find(CLUSTER_CONFIG["job_id"].to_i)
puts job.state
# TODO: save logs to s3 before shutting down cluster

############################

# class Nodes < ActiveResource::Base
#   self.site = CLUSTER_CONFIG['rest_url']
#   self.user = CLUSTER_CONFIG['admin_user']
#   self.password = CLUSTER_CONFIG['admin_password']
# end

