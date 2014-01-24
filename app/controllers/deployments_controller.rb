class DeploymentsController < ApplicationController
  
  before_filter :load_stage
  before_filter :ensure_deployment_possible, :only => [:new, :create]

  # GET /projects/1/stages/1/deployments
  # GET /projects/1/stages/1/deployments.xml
  def index
    @deployments = @stage.deployments

    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @deployments.to_xml }
    end
  end

  # GET /projects/1/stages/1/deployments/1
  # GET /projects/1/stages/1/deployments/1.xml
  def show
    @deployment = @stage.deployments.find(params[:id])
    set_auto_scroll
    
    respond_to do |format|
      format.html # show.rhtml
      format.xml  { render :xml => @deployment.to_xml }
      format.js { render :partial => 'status.html.erb' }
    end
  end

  # GET /projects/1/stages/1/deployments/new
  def new
    @deployment = @stage.deployments.new
    @deployment.task = params[:task]
    
    # Allow description to be passed in via a URL parameter
    @deployment.description = params[:description]
    
    if params[:repeat]
      @original = @stage.deployments.find(params[:repeat])
      @deployment = @original.repeat
    end
    
    @diff = ''
    if @deployment.task == 'deploy' && @stage.effective_configuration(:scm).value.to_s == ':git'
      deployer = Webistrano::Deployer.new(@deployment)
      config = deployer.instantiate_configuration
      config.load 'deploy'
      deployer.set_pre_vars(config)
      deployer.set_stage_configuration(config)
      web_dir = config.fetch(:deploy_to) + "/web"
      origin = config.source.origin
      branch = config.fetch(:branch)
      begin      
        @diff = config.capture("cd #{web_dir} && git fetch #{origin} && git log --oneline HEAD..#{origin}/#{branch}", {:hosts => @stage.hosts.first.name})
        @diff.strip!
        unless @diff.empty?
          @diff = "===== Commits ===== \n" + @diff + "\n\n===== Changed files =====\n"
          @diff += config.capture("cd #{web_dir} && git diff --name-status HEAD..#{origin}/#{branch}", {:hosts => @stage.hosts.first.name})        
        end
      rescue => e
        flash[:error] = "Unexpected error happened: #{e.message}"
      end
    end
  end

  # POST /projects/1/stages/1/deployments
  # POST /projects/1/stages/1/deployments.xml
  def create
    @deployment = Deployment.new
    
    respond_to do |format|
      if populate_deployment_and_fire
        
        @deployment.deploy_in_background!

        format.html { redirect_to project_stage_deployment_url(@project, @stage, @deployment)}
        format.xml  { head :created, :location => project_stage_deployment_url(@project, @stage, @deployment) }
      else
        @deployment.clear_lock_error
        format.html { render :action => "new" }
        format.xml  { render :xml => @deployment.errors.to_xml }
      end
    end
  end

  # GET /projects/1/stages/1/deployments/latest
  def latest
    @deployment = @stage.deployments.find(:first, :order => "created_at desc")

    respond_to do |format|
      format.html { render :action => "show"}
      format.xml do
        if @deployment
          render :xml => @deployment.to_xml
        else
          render :status => 404, :nothing => true
        end
      end
    end
  end
  
  # POST /projects/1/stages/1/deployments/1/cancel
  def cancel
    redirect_to "/" and return unless request.post?
    @deployment = @stage.deployments.find(:first, :order => "created_at desc")

    respond_to do |format|
      begin
        @deployment.cancel!
        
        flash[:notice] = "Cancelled deployment by killing it"
        format.html { redirect_to project_stage_deployment_url(@project, @stage, @deployment)}
        format.xml  { head :ok }
      rescue => e
        flash[:error] = "Cancelling failed: #{e.message}"
        format.html { redirect_to project_stage_deployment_url(@project, @stage, @deployment)}
        format.xml  do
          @deployment.errors.add("base", e.message)
          render :xml => @deployment.errors.to_xml 
        end
      end
    end
  end
  
  protected
  def ensure_deployment_possible
    if current_stage.deployment_possible?
        true
    else
      respond_to do |format|  
        flash[:error] = 'A deployment is currently not possible.'
        format.html { redirect_to project_stage_url(@project, @stage) }
        format.xml  { render :xml => current_stage.deployment_problems.to_xml }
        false
      end
    end
  end
  
  def set_auto_scroll
    if params[:auto_scroll].to_s == "true"
      @auto_scroll = true
    else
      @auto_scroll = false
    end
  end
  
  # sets @deployment
  def populate_deployment_and_fire
    return Deployment.lock_and_fire do |deployment|
      @deployment = deployment
      @deployment.attributes = params[:deployment]
      @deployment.prompt_config = params[:deployment][:prompt_config] rescue {}
      @deployment.stage = current_stage
      @deployment.user = current_user
    end
  end
  
end
