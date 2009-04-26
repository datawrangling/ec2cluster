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
        @job.nextstep!
        logger.debug( 'initiating background cluster launch...' )    
        # job state is now "launching_instances"...        
        # @job.launch_cluster
        Delayed::Job.enqueue ClusterLaunchJob.new(@job)
        flash[:notice] = 'Job was successfully submitted.'        
        
        format.html { redirect_to(@job) }
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
end
