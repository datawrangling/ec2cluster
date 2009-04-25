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
    
    
  #### VALIDATIONS ##############  
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
      # simulate long running task of launching an EC2 cluster
      i = 0
      while i < 20 do
         sleep 1
         i += 1
      end   
      # call method to kick off delayed_job here. 
      # will stick in "launching_instances" state until cluster is launched and
      # the delayed job background task calls nextstep! again.
      # the background job will need to check the DB periodically to see if state 
      # is cancellation_requested, in that case it will exit and let terminate_cluster clean up 
      # in which case it will exit execution
      ###### these should be set by at the end of the delayed_job:

      # t.string   "master_instance_id"
      # t.string   "master_hostname"
      # t.string   "master_public_hostname"

      # on exiting, the delayed_job  sets "submitted_at" as follows:
      # update_attribute(:submitted_at, Time.now )      
      self.nextstep!
      # job is now in  "running_job_commands" state
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

  # # This method is called from the controller and takes care of the processing
  # def submit
  #   begin
  #     submission_response = add_job_to_queue()
  #     puts submission_response
  #     self.submit!   
  #   rescue Exception 
  #     self.failed!
  #   end    
  # 
  # end  
                      
  
protected

  def set_start_time
    update_attribute(:started_at, Time.now )  
  end
  
  def set_finish_time
    update_attribute(:finished_at, Time.now )    
  end

  def set_rest_url
    hostname = Socket.gethostname
    self.mpi_service_rest_url = "http://#{hostname}:3000/jobs"    
  end
  
  def set_security_groups  
    # Same as Hadoop EC2 conventions...
    update_attribute(:master_security_group, "#{id}-master")
    update_attribute(:worker_security_group, "#{id}")
  end  

########## TODO rewrite ##############
  # # This method submits the bakcground job request
  # def add_job_to_queue
  #   #TODO... should this connection be opened every time?  I think there is an idle timeout, so yes for now.
  #   #TODO: wrap this in an exception handler in case the submission totally fails using right_aws
  #   sqs    = RightAws::SqsGen2.new(EC2PROCESSING_AWS_ACCESS_KEY_ID, EC2PROCESSING_AWS_SECRET_ACCESS_KEY)
  #   #TODO pull the queue name from the settings file as well...
  #   input_queue = sqs.queue(INPUT_QUEUE)
  #   @message = Base64.encode64(self.to_json)
  #   result = input_queue.send_message(@message)
  #   puts self.to_json
  # end
  # 
  # # This updates the stored filename with processed output location string
  # #TODO, need methods in REST web service to update these for a given job id will changing state be enough?
  # def set_output_filename
  #   update_attribute(:output_file_location, "#{output_file_location}")
  # end  
  # 
  # def set_error_message
  #   update_attribute(:error_message, "#{error_message}")
  # end

###########################################

  def number_of_instances_must_be_at_least_1
    errors.add(:number_of_instances, 'You need at least 1 node in your cluster') if number_of_instances < 1
  end  

  # TODO: verify S3 buckets exist using right_aws
  # t.string   "output_path" 
  # t.string   "log_path"

  # TODO: verify s3 input files are accesible using right_aws
  # t.text     "input_files" 
  
end
