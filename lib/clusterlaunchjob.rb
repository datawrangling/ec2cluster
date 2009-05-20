class ClusterLaunchJob
  attr_accessor :job_id

  def initialize(job)
    self.job_id = job.id
  end

  def perform
    # stuff to do when job is popped off queue
    job = Job.find(job_id)
    job.launch_cluster   
  end

end