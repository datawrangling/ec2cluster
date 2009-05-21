# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  before_filter :redirect_to_ssl
  before_filter :authenticate # v1.0 is an internal app with single admin user
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password
  
protected
  def authenticate
    authenticate_or_request_with_http_basic do |username, password|
      username == APP_CONFIG['admin_user'] && password == APP_CONFIG['admin_password']
    end
  end
  
  def redirect_to_ssl
    if ENV["RAILS_ENV"] == "production"
      redirect_to url_for params.merge({:protocol => 'https://'})
    end
  end
  
end