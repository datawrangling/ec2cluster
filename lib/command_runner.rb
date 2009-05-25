#!/usr/bin/env ruby 

# == Synopsis 
#   This is a sample description of the application.
#   Blah blah blah.
#
# == Examples
#   This command does blah blah blah.
#     command_runner foo.txt
#
#   Other examples:
#     command_runner -q bar.doc
#     command_runner --verbose foo.html
#
# == Usage 
#   command_runner [options] source_file
#
#   For help use: command_runner -h
#
# == Options
#   -h, --help          Displays help message
#   -v, --version       Display the version, then exit
#   -q, --quiet         Output as little as possible, overrides verbose
#   -V, --verbose       Verbose output
#   TO DO - add additional options
#
# == Author
#   Data Wrangling, LLC
#
# == Copyright
#   Copyright (c) 2009 Data Wrangling, LLC. Licensed under the BSD License:
#   http://www.opensource.org/licenses/bsd-license.php

# TODO - update Synopsis, Examples, etc


require 'optparse' 
require 'rdoc/usage'
require 'ostruct'
require 'date'
require 'rubygems'
require 'activeresource'
require 'right_aws'
require 'net/http'

# TODO, set these from YAML file, commandline arg "--config", pointing to /home/elasticwulf/config.yml
CLUSTER_CONFIG = YAML.load_file("/Users/pskomoroch/cluster_config.yml")
puts CLUSTER_CONFIG['job_id']



class Job < ActiveResource::Base
  self.site = CLUSTER_CONFIG['rest_url']
  self.user = CLUSTER_CONFIG['admin_user']
  self.password = CLUSTER_CONFIG['admin_password']
end


#############################

# # look at instance metadata to determine if the node is a master or a slave....
url = 'http://169.254.169.254/latest/meta-data/security-groups'
# security_groups = Net::HTTP.get_response(URI.parse(url)).body
security_groups = "default\n28-elasticwulf-master-052409-0222AM"

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

# TODO , need node model in order to check cluster status in job model (node belongs to a job)

# these values are set by the launch_instances method, which needs to be configured to launch N slave nodes... 

# [{:aws_image_id       => "ami-e444444d",
#   :aws_reason         => "",
#   :aws_state_code     => "0",
#   :aws_owner          => "000000000888",
#   :aws_instance_id    => "i-123f1234",
#   :aws_reservation_id => "r-aabbccdd",
#   :aws_state          => "pending",
#   :dns_name           => "",
#   :ssh_key_name       => "my_awesome_key",
#   :aws_groups         => ["my_awesome_group"],
#   :private_dns_name   => "",
#   :aws_instance_type  => "m1.small",
#   :aws_launch_time    => "2008-1-1T00:00:00.000Z"
#   :aws_ramdisk_id     => "ari-8605e0ef"
#   :aws_kernel_id      => "aki-9905e0f0",
#   :ami_launch_index   => "0",
#   :aws_availability_zone => "us-east-1b"
#   }]

# 

# ./script/generate scaffold node job:references aws_image_id:text \
# aws_instance_id:text aws_state:text dns_name:text \
# ssh_key_name:text aws_groups:text private_dns_name:text \
# aws_instance_type:text aws_launch_time:text aws_availability_zone:text \
# is_configured:boolean

# all strings except is_configured

# job_id
# aws_image_id
# aws_instance_id
# aws_state
# dns_name
# ssh_key_name
# aws_groups  aws_groups.join(' ')
# private_dns_name
# aws_instance_type
# aws_launch_time
# aws_availability_zone
# is_configured (boolean)
# boolean

def clusterstatus
  @job = Job.find(params[:id])
  configured_count = @job.nodes.count(:all, :conditions => {:is_configured => true })
  if configured_count == @job.number_of_instances:
    return 'ready'
  else
    return '#{configured_count} of #{@job.number_of_instances} nodes configured'   
end



# # if it is a master node, we do configure_master_node(), then wait on cluster_configured?
# cluster_configured just 


#   configure_master_node()
#   Until cluster_configured?
#     sleep(10)
# # when configured:
#   download_inputs()
#   run_command()
#   upload_outputs()
# # wrap everything in a try/rescue block which triggers 'error'


############################

# Get Job attributes (input file names etc...)


job = Job.find(CLUSTER_CONFIG["job_id"].to_i)
puts job.master_instance_id
puts job.state


###########################
# Wait for clusterstatus to return 'ready'

#TODO add clusterstatus method



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
s3.put('datawrangling', 'cluster_launch_job.rb',  File.open('cluster_launch_job.rb'))

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

# TODO: add Node model, and erb view which can automatically render a hosts file for the master node....
# TODO: add clusterstatus method to Jobs model that does a count(*) from nodes where state = configured.  Job.nodes(state=configured) 

# GET clusterstatus 

# need to add a custom GET action /clusterstatus where the master can see if all the worker nodes have finished nfs mounting... 
# cluster boot script on master periodically checks with REST server to see if cluster is configured 
# /clusterstatus is custom action for a job which checks how many nodes have reported they are configured...the logic of that method just checks to see if number_of_instances == configured_instances, where configured instances is just a count(*) from nodes where state = configured , then clusterstatus will report back 'live' , else it will report back 'booting'.
# when the masternode gets a response of 'live', it will send a progress update 'booting MPI', then do an mpd boot to initiate the MPI ring, test that mpi is working, send an update on progress that mpi has booted, then kick off the job command and send a /nextstep ping to the REST server.










# class App
#   VERSION = '0.0.1'
#   
#   attr_reader :options
# 
#   def initialize(arguments, stdin)
#     @arguments = arguments
#     @stdin = stdin
#     
#     # Set defaults
#     @options = OpenStruct.new
#     @options.verbose = false
#     @options.quiet = false
#     # TO DO - add additional defaults
#   end
# 
#   # Parse options, check arguments, then process the command
#   def run
#         
#     if parsed_options? && arguments_valid? 
#       
#       puts "Start at #{DateTime.now}\n\n" if @options.verbose
#       
#       output_options if @options.verbose # [Optional]
#             
#       process_arguments            
#       process_command
#       
#       puts "\nFinished at #{DateTime.now}" if @options.verbose
#       
#     else
#       output_usage
#     end
#       
#   end
#   
#   protected
#   
#     def parsed_options?
#       
#       # Specify options
#       opts = OptionParser.new 
#       opts.on('-v', '--version')    { output_version ; exit 0 }
#       opts.on('-h', '--help')       { output_help }
#       opts.on('-V', '--verbose')    { @options.verbose = true }  
#       opts.on('-q', '--quiet')      { @options.quiet = true }
#       # TO DO - add additional options
#             
#       opts.parse!(@arguments) rescue return false
#       
#       process_options
#       true      
#     end
# 
#     # Performs post-parse processing on options
#     def process_options
#       @options.verbose = false if @options.quiet
#     end
#     
#     def output_options
#       puts "Options:\n"
#       
#       @options.marshal_dump.each do |name, val|        
#         puts "  #{name} = #{val}"
#       end
#     end
# 
#     # True if required arguments were provided
#     def arguments_valid?
#       # TO DO - implement your real logic here
#       true if @arguments.length == 1 
#     end
#     
#     # Setup the arguments
#     def process_arguments
#       # TO DO - place in local vars, etc
#     end
#     
#     def output_help
#       output_version
#       RDoc::usage() #exits app
#     end
#     
#     def output_usage
#       RDoc::usage('usage') # gets usage from comments above
#     end
#     
#     def output_version
#       puts "#{File.basename(__FILE__)} version #{VERSION}"
#     end
#     
#     def process_command
#       # TO DO - do whatever this app does
#       
#       #process_standard_input # [Optional]
#     end
# 
#     def process_standard_input
#       input = @stdin.read      
#       # TO DO - process input
#       
#       # [Optional]
#       #@stdin.each do |line| 
#       #  # TO DO - process each line
#       #end
#     end
# end
# 
# 
# # TO DO - Add your Modules, Classes, etc
# 
# 
# # Create and run the application
# app = App.new(ARGV, STDIN)
# app.run
