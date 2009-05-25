class NodesController < ApplicationController
  layout 'green'
  
  
  before_filter :find_job
  
  # GET /nodes
  # GET /nodes.xml
  def index
    @nodes = @job.nodes.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @nodes }
      format.json  { render :json => @nodes }
    end
  end

  # GET /nodes/1
  # GET /nodes/1.xml
  def show
    @node = Node.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @node }
      format.json  { render :json => @node }      
    end
  end

  # GET /nodes/new
  # GET /nodes/new.xml
  def new
    @node = @job.nodes.build 
    
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @node }
      format.json  { render :json => @node }      
    end
  end

  # GET /nodes/1/edit
  def edit
    @node = @job.nodes.find(params[:id])
  end

  # POST /nodes
  # POST /nodes.xml
  def create
    @node = Node.new(params[:node])

    respond_to do |format|
      if (@job.nodes << @node)
        flash[:notice] = 'Node was successfully created.'
        format.html { redirect_to job_url(@job) }
        format.xml  { render :xml => @node, :status => :created, :location => @node }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @node.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /nodes/1
  # PUT /nodes/1.xml
  def update
    @node = @job.nodes.find(params[:id])
    
    respond_to do |format|
      if @node.update_attributes(params[:node])
        @ready_nodes = @job.nodes.find(:all, :conditions => {:is_configured => true })
        if @ready_nodes.count == @job.number_of_instances and @job.state == "waiting_for_nodes"
          @job.nextstep!  # waiting_for_nodes - > configuring_cluster
          puts "All nodes report ready, configuring cluster"
        end        
        flash[:notice] = 'Node was successfully updated.'
        format.html { redirect_to job_url(@job) }
        format.xml  { head :ok }
        format.json  { head :ok }        
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @node.errors, :status => :unprocessable_entity }
        format.json  { render :json => @job.errors, :status => :unprocessable_entity }         
      end
    end
  end

  # DELETE /nodes/1
  # DELETE /nodes/1.xml
  def destroy
    node = @job.nodes.find(params[:id])
    @job.nodes.delete(node)

    respond_to do |format|
      format.html { redirect_to job_url(@job) }
      format.xml  { head :ok }
    end
  end
  
  
  
private

  def find_job
    @job_id = params[:job_id]
    return(redirect_to(jobs_url)) unless @job_id
    @job = Job.find(@job_id)
  end
  
end
