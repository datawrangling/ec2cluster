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
    self[:master_ami_id] or 'ami-71fd1a18'
  end
  
  def worker_ami_id
    self[:worker_ami_id] or 'ami-71fd1a18'
  end  
  
  def instance_type
    self[:instance_type] or 'c1.medium'
  end  
  
  def availability_zone
    self[:availability_zone] or 'us-east-1c'
  end
  
  def mpi_version
    self[:mpi_version] or 'openmpi'
  end  
  
  ### Protected fields ##########
  # autopopulated by rails
  attr_protected :created_at, :updated_at
  
  # populated by job model itself (in state_machine blocks)
  attr_protected :mpi_service_rest_url, :submitted_at, :started_at, :finished_at
  
  # populated by ClusterJob worker daemon
  attr_protected :master_security_group, :worker_security_group
  attr_protected :master_instance_id, :master_hostname, :master_public_hostname
    
    
  #### Validations ##############  
  # These should at least be present (log_path, keypair, EBS vols are optional)
  validates_presence_of :name, :description, :commands, :input_files, :output_files, :output_path
  validates_numericality_of :user_id, :number_of_instances
  # these should be in the set of valid Amazon EC2 instance types...
  validates_inclusion_of :instance_type, :in => %w( m1.small m1.large m1.xlarge c1.medium c1.xlarge), :message => "instance type {{value}} is not an allowed EC2 instance type"
  validate :number_of_instances_must_be_at_least_1
  # TODO, these vary by EC2 account, check set using right_aws
  validates_inclusion_of :availability_zone, :in => %w( us-east-1a us-east-1b us-east-1c), :message => "availability zone {{value}} is not an allowed EC2 availability zone"  
  # TODO- make this a check against EC2 api describe-images with right_aws
  validates_format_of [:worker_ami_id, :master_ami_id], 
                      :with => %r{^ami-}i,
                      :message => 'must be a valid Amazon EC2 AMI'
                     
  ####  acts_as_state_machine transitions ############
                       
  aasm_column :state
  aasm_initial_state :pending
  aasm_state :pending   
  aasm_state :launching_instances
  aasm_state :running_job_commands, :enter => :set_start_time # instances launched
  aasm_state :terminating_instances, :enter => :terminate_cluster # kick off background task
  aasm_state :complete, :enter => :set_finish_time #instances terminated
  aasm_state :cancellation_requested, :enter => :terminate_cluster # kick off background task
  aasm_state :cancelled, :enter => :set_finish_time #instances terminated
  aasm_state :terminating_due_to_error, :enter => :terminate_cluster # kick off background task  
  aasm_state :failed, :enter => :set_finish_time #instances terminated
  
  aasm_event :nextstep do
    transitions :to => :launching_instances, :from => [:pending]  
    transitions :to => :running_job_commands, :from => [:launching_instances]  
    transitions :to => :terminating_instances, :from => [:running_job_commands]
    transitions :to => :complete, :from => [:terminating_instances]
    transitions :to => :cancelled, :from => [:cancellation_requested]
    transitions :to => :failed, :from => [:terminating_due_to_error]       
  end  
  
  aasm_event :cancel do
    transitions :to => :cancellation_requested, :from => [:pending, :launching_instances, :running_job_commands]
  end  
  
  aasm_event :error do
    transitions :to => :terminating_due_to_error, :from => [:launching_instances, :running_job_commands]
  end  


  def initialize_job_parameters
    self.set_rest_url
    self.set_security_groups
  end


  def launch_cluster
    # this method is called from the controller create method
    begin      
      
      # TODO: the background job will need to check the DB periodically while the ec2 launch script
      # is running to see if state = cancellation_requested, in that case it will exit and
      # let the terminate_cluster background job clean up 
      # periodically update the progress field with text string of number of instances launched
            
      # TODO: pass cluster launch script the job description record as json metadata for
      # the masternode command service to parse and execute using parameterized launch...
      # @message = Base64.encode64(self.to_json) 
      # or just self.to_json    
            
      # simulate long running task of launching an EC2 cluster
      i = 0
      while i < 20 do
         sleep 1
         i += 1
      end    

      self.set_master_instance_metadata
      self.nextstep!
      # job is now in  "running_job_commands" state
      # The job will stay in "running_job_commands" state until cluster is launched and
      # the delayed job background task calls nextstep! again when it finishes.      
      logger.debug( 'cluster launched...' )
    rescue Exception 
      self.error!
      logger.debug( 'there was an error launching the cluster...' )
    end
  end
  
  def terminate_cluster
    # prior state could be: terminating_instances, cancellation_requested, 
    # or terminating_due_to_error
    puts 'background cluster shutdown initiated...'  
    # call method to kick off delayed_job here. 
    # will stick in entry state until cluster is terminated and
    # the delayed job background task calls nextstep! again.
  end  
  
  # TODO add methods to be called by worker via rest url and custom controller actions:
  # t.string   "progress"
  # t.text     "error_message"
                        
protected
  def set_start_time
    # Time when the cluster has actually booted
    update_attribute(:started_at, Time.now ) 
  end
      
  def set_submit_time
    # Time the actual command starts running on ec2  
    update_attribute(:submitted_at, Time.now )  
  end
  
  def set_finish_time
    update_attribute(:finished_at, Time.now )    
  end

  def set_rest_url
    # TODO load port number from custom application settings YAML
    hostname = Socket.gethostname
    self.mpi_service_rest_url = "http://#{hostname}:3000/jobs"    
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
