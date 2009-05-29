#!/usr/bin/env ruby 

# command_runner.rb NUMBER_OF_CPUS

# This script is only run on the master node of the cluster as the "elasticwulf" user from within the NFS home directory "/home/elasticwulf/".  It fetches input & code from s3, runs the job command, and uploads outputs to S3.  The job command it runs will typically be a bash script containing MPI commands run across the entire cluster using the input data fetched from S3 which is available to all nodes via NFS.

# Convention is for the supplied command to write all files to the working directory or a path relative to /home/elasticwulf/

require 'rubygems'
require 'activeresource'
require 'right_aws'
require 'net/http'

CPU_COUNT=ARGV[0]
ENV['CPU_COUNT'] = CPU_COUNT

CLUSTER_CONFIG = YAML.load_file("/home/elasticwulf/cluster_config.yml")
puts "job id: " + CLUSTER_CONFIG['job_id'].to_s

@s3handle = RightAws::S3Interface.new(CLUSTER_CONFIG['aws_access_key_id'],
            CLUSTER_CONFIG['aws_secret_access_key'], {:multi_thread => true})

def fetch_s3file(s3filepath, localfile, s3handle)
  # example fetch http://datawrangling.s3.amazonaws.com/colbert_2.gif 
  # fetch_s3file('datawrangling/colbert_2.gif', 'colbert_2.gif')
  # TODO: this works for indivudal files, what about directories?  we should detect if supplied path is
  # a directory or a file, if a directory, bulk upload entire driectory. maybe better to call s3command?
  s3pathlist = s3filepath.split("/")
  bucket = s3pathlist[0]
  key = s3pathlist[1,s3pathlist.size].join('/')    
  filestream = File.new(localfile, File::CREAT|File::RDWR)
  rhdr = s3handle.get(bucket, key) do |chunk| filestream.write(chunk) end
  filestream.close
end

def upload_s3file(output_path, localfile, s3handle)
  # better convention might be to accept a pattern, i.e. foo*, which will grab all files matching that pattern.
  # we can do an ls on that pattern and then iterate over the results. Or possibly detect if supplied path is
  # a directory or a file, if a directory, bulk upload entire driectory.  
  bucket = output_path
  s3path=""
  output_elements = output_path.split('/')
  if output_elements.size > 1
    bucket = output_elements[0]
    s3path = output_elements[1,output_elements.size].join("/")
  end
  
  if s3path.size > 0
    s3key = s3path + "/" + localfile
  else 
    s3key = localfile
  end  
  
  s3handle.put(bucket, s3key, File.open(localfile))
end

# Create an ActiveResource connection to the Elasticwulf REST web service
class Job < ActiveResource::Base
  self.site = CLUSTER_CONFIG['rest_url']
  self.user = CLUSTER_CONFIG['admin_user']
  self.password = CLUSTER_CONFIG['admin_password']
end

job = Job.find(CLUSTER_CONFIG["job_id"].to_i)


# TODO refactor into main method and helper methods

############################
# Fetch files from s3 to local working directory
job.put(:updateprogress, :progress => 'downloading inputs from S3')
puts job.progress

input_files = job.input_files.split

input_files.each do |s3filepath|
  puts "fetching " + s3filepath
  fetch_s3file(s3filepath, s3filepath.split("/")[-1], @s3handle)
end

############################
# Run job command and wait for completion, periodically updating progress
job.put(:nextstep)  # Signal REST service, job state will transition from configuring cluster -> running_job
puts job.state

# TODO: kick off command as a thread or child process with popen4
system(job.commands)

# TODO: wrap the main section in a try/rescue block which puts 'error' for the job state in case of failure
# # PUT an update by invoking the 'error' REST method, 
# puts "triggering error..."
# job.put(:error, :error_message => 'some horrible error message')
# job = Job.find(CLUSTER_CONFIG["job_id"].to_i)
# puts job.state

############################
# Upload job output files to S3
job.put(:updateprogress, :progress => 'uploading outputs to S3')
puts job.progress

output_path = job.output_path  
output_files = job.output_files.split

output_files.each do |file|
  puts "uploading " + file
  upload_s3file(output_path, file, @s3handle)
end

#############################
# Cleanup and exit, triggering cluster shutdown
# TODO: save logs to s3 before shutting down cluster
job.put(:nextstep)  # Signal REST service, job state will transition from running_job -> shutdown_requested









