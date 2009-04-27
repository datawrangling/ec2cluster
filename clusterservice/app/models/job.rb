class Job < ActiveRecord::Base
  include AASM
  
  # Set defaults 
  # see http://www.jroller.com/obie/entry/default_values_for_activerecord_attributes
  
  # The default setting is for the cluster to shut itself down when the job completes
  def shutdown_after_complete
    self[:shutdown_after_complete] or true
  end
  
  # default base 32 bit Ubuntu amis
  # see http://alestic.com/ for details
  def master_ami_id
    self[:master_ami_id] or APP_CONFIG['defult_master_ami_id']
  end
  
  def worker_ami_id
    self[:worker_ami_id] or APP_CONFIG['defult_worker_ami_id']
  end  
  
  def instance_type
    self[:instance_type] or APP_CONFIG['defult_instance_type']
  end  
  
  def availability_zone
    self[:availability_zone] or APP_CONFIG['defult_availability_zone']
  end
  
  def mpi_version
    self[:mpi_version] or APP_CONFIG['defult_mpi_version']
  end  
  
  ### Protected fields ##########
  # autopopulated by rails
  attr_protected :created_at, :updated_at
  
  # populated by job model itself (in state_machine blocks)
  attr_protected :mpi_service_rest_url, :started_at, :finished_at, :cancelled_at, :failed_at
  
  # populated by ClusterJob worker daemon
  attr_protected :master_security_group, :worker_security_group
  attr_protected :master_instance_id, :master_hostname, :master_public_hostname
    
    
  #### Validations ##############  
  # These should at least be present (log_path, keypair, EBS vols are optional)
  validates_presence_of :name, :description, :commands, :input_files, :output_files, :output_path
  validates_numericality_of :user_id, :number_of_instances
  # these should be in the set of valid Amazon EC2 instance types...
  validates_inclusion_of :instance_type, :in => %w( m1.small m1.large m1.xlarge c1.medium c1.xlarge), :message => "instance type {{value}} is not an allowed EC2 instance type, must be in: m1.small m1.large m1.xlarge c1.medium c1.xlarge"
  validate :number_of_instances_must_be_at_least_1
  # TODO, these vary by EC2 account, check set using right_aws
  validates_inclusion_of :availability_zone, :in => %w( us-east-1a us-east-1b us-east-1c), :message => "availability zone {{value}} is not an allowed EC2 availability zone, must be in: us-east-1a us-east-1b us-east-1c"  
  # TODO- make this a check against EC2 api describe-images with right_aws
  validates_format_of [:worker_ami_id, :master_ami_id], 
                      :with => %r{^ami-}i,
                      :message => 'must be a valid Amazon EC2 AMI'
                     
  ####  acts_as_state_machine transitions ############
                       
  aasm_column :state
  aasm_initial_state :pending
  aasm_state :pending
  aasm_state :launch_pending     
  aasm_state :launching_instances
  aasm_state :configuring_cluster
  aasm_state :waiting_for_jobs
  aasm_state :running_job, :enter => :set_start_time # instances launched
  
  aasm_state :shutdown_requested, :enter => :terminate_cluster_later
  aasm_state :shutting_down_instances
  aasm_state :complete, :enter => :set_finish_time #instances terminated
  
  aasm_state :cancellation_requested, :enter => :terminate_cluster_later
  aasm_state :cancelling_job
  aasm_state :cancelled, :enter => :set_cancelled_time #instances terminated
  
  aasm_state :termination_requested, :enter => :terminate_cluster_later
  aasm_state :terminating_job     
  aasm_state :failed, :enter => :set_failed_time #instances terminated
  
  aasm_event :nextstep do
    transitions :to => :launch_pending, :from => [:pending]     
    transitions :to => :launching_instances, :from => [:launch_pending]  
    transitions :to => :configuring_cluster, :from => [:launching_instances] 
    transitions :to => :running_job, :from => [:configuring_cluster]
    transitions :to => :running_job, :from => [:waiting_for_jobs]  
      
    transitions :to => :shutdown_requested, :from => [:running_job]
    transitions :to => :shutting_down_instances, :from => [:shutdown_requested]
    transitions :to => :complete, :from => [:shutting_down_instances]
    
    transitions :to => :cancelling_job, :from => [:cancellation_requested]
    transitions :to => :cancelled, :from => [:cancelling_job]    
    
    transitions :to => :terminating_job, :from => [:termination_requested] 
    transitions :to => :failed, :from => [:terminating_job]       
          
  end  
  
  # TODO: if shutdown_after_complete is false, The master node service will
  # call this action instead of nextstep... not implemented yet so cluster always
  # shuts down after job completes.
  aasm_event :wait do
    transitions :to => :waiting_for_jobs, :from => [:running_job]
  end  
  
  aasm_event :cancel do
    transitions :to => :cancellation_requested, 
    :from => [
      :pending,
      :launch_pending, 
      :launching_instances,
      :configuring_cluster, 
      :running_job, 
      :waiting_for_jobs
    ]
  end  
  
  aasm_event :error do
    transitions :to => :termination_requested, 
    :from => [
      :pending,
      :launch_pending, 
      :launching_instances,
      :configuring_cluster, 
      :running_job,
      :waiting_for_jobs,
      :shutdown_requested,
      :shutting_down_instances,
      :cancellation_requested,
      :cancelling_job,
      :termination_requested,
      :terminating_job
    ]
  end  


  def initialize_job_parameters
    self.set_rest_url
    self.set_security_groups
  end

  def is_cancellable?
    #TODO: add active record model for job states, to hold these types of properties...
    cancellable_states = [
      "pending",
      "launch_pending",
      "launching_instances",
      "configuring_cluster",
      "configuring_cluster",
      "waiting_for_jobs",
      "running_job"
      ]
    return cancellable_states.include? self.state 
  end


  def launch_cluster
    # this method is called from the controller create method
    begin      
      self.nextstep! # launch_pending -> launching_instances
      # TODO: the background job will need to check the DB periodically while the ec2 launch script
      # is running to see if state = cancellation_requested, in that case it will exit and
      # let the terminate_cluster background job clean up 
      # periodically update the progress field with text string of number of instances launched
            
      # TODO: pass cluster launch script the job description record as json metadata for
      # the masternode command service to parse and execute using parameterized launch...
      # @message = Base64.encode64(self.to_json) 
      # or just self.to_json    
      
      #use right_aws to launch nstances
      @ec2   = RightAws::Ec2.new(APP_CONFIG['aws_access_key_id'],
                                  APP_CONFIG['aws_secret_access_key'])
                
      # simulate long running task of launching an EC2 cluster
      i = 0
      while i < 20 do
         sleep 1
         i += 1
      end    

      self.set_master_instance_metadata
      self.nextstep!  # launching_instances -> configuring_cluster
      # job is now in  "configuring_cluster" state.... 
      # The job will stay in "configuring_cluster" state until cluster is set up (NFS etc)
      # and the Master Node reports back that it is running via the custom action...
      # the job will stay in a running_job state until the master node reports back again
      # to the REST api, then the state will become "terminating_instances"... and the custom action
      # "terminate" is called.     
      
    rescue Exception 
      self.error! # launching_instances -> terminating_due_to_error
      # do something with error...
    end
  end
  

  def terminate_cluster_later
    # push cluster termination off to background using delayed_job
    self.send_later(:terminate_cluster)
  end
 
  
  def terminate_cluster
    # prior state could be: terminating_instances, cancellation_requested, 
    # or terminating_due_to_error
    self.nextstep! # cancellation_requested -> cancelling_job
    
    puts 'background cluster shutdown initiated...'  
  
    # simulate long running task of shutting down an EC2 cluster
    i = 0
    while i < 20 do
       sleep 1
       i += 1
    end    
  
    # call method to kick off delayed_job here. 
    # will stick in entry state until cluster is terminated and
    # the delayed job background task calls nextstep! again.
    
    self.nextstep! # cancelling_job -> cancelled
  end  
  
  # TODO add methods to be called by worker via rest url and custom controller actions:
  # t.string   "progress"
  # t.text     "error_message"
    

                        
protected


  def set_start_time
    # Time when the cluster has actually booted and MPI job starts running
    update_attribute(:started_at, Time.now ) 
  end
  
  def set_finish_time
    update_attribute(:finished_at, Time.now )    
  end
  
  def set_cancelled_time
    update_attribute(:cancelled_at, Time.now )    
  end
  
  def set_failed_time
    update_attribute(:failed_at, Time.now )    
  end    

  def set_rest_url
    hostname = Socket.gethostname
    port = APP_CONFIG['rails_application_port']
    self.mpi_service_rest_url = "http://#{hostname}:#{port}/"    
  end
  
  def set_security_groups  
    # Same as Hadoop EC2 conventions...
    update_attribute(:master_security_group, "#{id}-master")
    update_attribute(:worker_security_group, "#{id}")
  end  

  def set_master_instance_metadata
    # TODO: these should be filled in with values obtained from a right_aws query 
    # or by using parameters passed into the method obtained by parsing the 
    # command line output of the launch script at the end of the delayed_job
    update_attribute(:master_instance_id, 'i-495ad120' )
    update_attribute(:master_hostname, 'domU-12-31-39-03-BD-B2.compute-1.internal' )
    update_attribute(:master_public_hostname, 'ec2-75-101-230-51.compute-1.amazonaws.com' )
  end  


  def number_of_instances_must_be_at_least_1
    errors.add(:number_of_instances, 'You need at least 1 node in your cluster') if number_of_instances < 1
  end  

  # TODO: verify S3 buckets exist using right_aws
  # t.string   "output_path" 
  # t.string   "log_path"

  # TODO: verify s3 input files are accesible using right_aws
  # t.text     "input_files" 
  
end
