
class JobsController < ApplicationController
  layout 'green'
  
  # GET /jobs
  # GET /jobs.xml
  def index
    @jobs = Job.paginate :page => params[:page], :order => 'created_at DESC', :per_page =>10

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @jobs }
      format.json  { render :json => @jobs }
    end
  end

  # GET /jobs/1
  # GET /jobs/1.xml
  def show
    @job = Job.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @job }
      format.json  { render :json => @job }
    end
  end

  # GET /jobs/new
  # GET /jobs/new.xml
  def new
    @job = Job.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @job }
      format.json  { render :json => @job }
    end
  end

  # GET /jobs/1/edit
  def edit
    @job = Job.find(params[:id])
  end

  # POST /jobs
  # POST /jobs.xml
  def create
    @job = Job.new(params[:job])

    respond_to do |format|
      if @job.save
        # after @job.save, initially the job is in a "pending" state.
        @job.initialize_job_parameters      
        @job.nextstep!  # pending - > launch_pending
        logger.debug( 'initiating background cluster launch...' )    
        # job state is now "launching_instances"...        
        Delayed::Job.enqueue ClusterLaunchJob.new(@job)   
        flash[:notice] = 'Job was successfully submitted.'          

        format.html { redirect_to(jobs_url) }
        format.xml  { render :xml => @job, :status => :created, :location => @job }
        format.json  { render :json => @job, :status => :created, :location => @job }        
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @job.errors, :status => :unprocessable_entity }
        format.json  { render :json => @job.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /jobs/1
  # PUT /jobs/1.xml
  def update
    @job = Job.find(params[:id])

    respond_to do |format|
      if @job.update_attributes(params[:job])
        flash[:notice] = 'Job was successfully updated.'
        format.html { redirect_to(@job) }
        format.xml  { head :ok }
        format.json  { head :ok }    
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @job.errors, :status => :unprocessable_entity }
        format.json  { render :json => @job.errors, :status => :unprocessable_entity }        
      end
    end
  end


  # DELETE /jobs/1
  # DELETE /jobs/1.xml
  def destroy
    @job = Job.find(params[:id])
    @job.destroy

    respond_to do |format|
      format.html { redirect_to(jobs_url) }
      format.xml  { head :ok }
      format.json  { head :ok }
    end
  end
  
#### Custom Actions #########  
  
  # PUT /jobs/1/cancel
  def cancel
    @job = Job.find(params[:id])
    logger.debug( 'initiating background cluster termination...' )    
    @job.cancel!
    # Delayed::Job.enqueue ClusterTerminateJob.new(@job)
    flash[:notice] = 'Cancellation request submitted...'
    logger.debug( 'Cancellation request recieved for Job!...' ) 

    respond_to do |format|
      format.html { redirect_to(jobs_url) }
      format.xml  { render :xml => @job }
      format.json  { render :json => @job }
    end
  end
  
  
  # PUT /jobs/1/nextstep
  def nextstep
    # called remotely by the running job cluster on EC2
    # Transistions job to next natural step in workflow,
    # i.e. "configuring_cluster" -> "running_job"
    @job = Job.find(params[:id])
    logger.debug( 'triggering next job step' )    
    @job.nextstep!
    flash[:notice] = 'triggering next job step..'
    logger.debug( 'next job step transition triggered' ) 

    respond_to do |format|
      format.html { redirect_to(jobs_url) }
      format.xml  { render :xml => @job }
      format.json  { render :json => @job }
    end
  end  
  
  # PUT /jobs/1/updateprogress
  def updateprogress
    @job = Job.find(params[:id])
    logger.debug( 'updating progress to #{params[:progress]}' ) 
    @job.progress = params[:progress]
    @job.save

    respond_to do |format|
      format.html { redirect_to(jobs_url) }
      format.xml  { render :xml => @job }
      format.json  { render :json => @job }
    end
  end
  
  # PUT /jobs/1/error
  def error
    @job = Job.find(params[:id])
    logger.debug( 'updating error_message to #{params[:error_message]}' ) 
    @job.error_message = params[:error_message]
    @job.save
    @job.error!

    respond_to do |format|
      format.html { redirect_to(jobs_url) }
      format.xml  { render :xml => @job }
      format.json  { render :json => @job }
    end
  end    
      
  
  # GET /jobs/refresh
  def refresh
    @jobs = Job.paginate :page => params[:page], :order => 'created_at DESC', :per_page =>10
  end  
  
end
