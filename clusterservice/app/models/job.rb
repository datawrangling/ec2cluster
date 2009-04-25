class Job < ActiveRecord::Base
  
  # Set defaults (see http://www.jroller.com/obie/entry/default_values_for_activerecord_attributes)
  
  # cluster shuts down by default when the job completes...
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
  
  # autopopulated by rails
  attr_protected :created_at, :updated_at
  
  # populated by job model itself (in state_machine blocks)
  attr_protected :mpi_service_rest_url, :submitted_at, :started_at, :finished_at
  
  # populated by ClusterJob worker daemon
  attr_protected :master_security_group, :worker_security_group
  attr_protected :master_instance_id, :master_hostname, :master_public_hostname
    
  # should at least be present (log_path, keypair, EBS vols are optional)
  validates_presence_of :name, :description, :commands, :input_files, :output_files, :output_path

  validates_numericality_of :user_id, :number_of_instances
  
  # should be in set of valid ec2 instance types...
  validates_inclusion_of :instance_type, :in => %w( m1.small m1.large m1.xlarge c1.medium c1.xlarge), :message => "instance type {{value}} is not an allowed EC2 instance type"
  
  # should be >= 1 
  validate :number_of_instances_must_be_at_least_1
  
  # should be in allowed ec2 zones...
  # TODO, these vary by EC2 account, check set using right_aws
  validates_inclusion_of :availability_zone, :in => %w( us-east-1a us-east-1b us-east-1c), :message => "availability zone {{value}} is not an allowed EC2 availability zone"  
  
  # TODO- make this a check against EC2 api describe-images with right_aws
  validates_format_of :worker_ami_id, 
                      :with => %r{^ami-}i,
                      :message => 'must be a valid Amazon EC2 AMI'
  
protected
  def number_of_instances_must_be_at_least_1
    errors.add(:number_of_instances, 'You need at least 1 node in your cluster') if number_of_instances < 1
  end  

  # TODO: verify S3 buckets exist using right_aws
  # t.string   "output_path" 
  # t.string   "log_path"

  # TODO: verify s3 input files are accesible using right_aws
  # t.text     "input_files" 
  
end
