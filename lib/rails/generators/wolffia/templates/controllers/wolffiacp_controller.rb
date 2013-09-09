class WolffiacpController < ActionController::Base
  protect_from_forgery

  def index
  	@users = User.find(:all)

  	if !@users.nil? && @users.size==0 then
  		redirect_to "/wolffiacp/install"
  	else  	
  		render :layout => "wolffiacp"
  	end
  end


  def install
	render :layout => "wolffiacp"
  end  
end
