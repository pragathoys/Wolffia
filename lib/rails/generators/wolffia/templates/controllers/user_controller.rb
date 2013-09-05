class UsersController < ApplicationController
	skip_before_filter :require_login, :only => [:new, :create]
	
	before_filter :allow_administrators

	def allow_administrators
	if session[:user_role_level] != 1 then
	  flash[:notice] = "Only administrators can access this page."
	  redirect_to root_url
	end
	end 


	def index
		@users = User.find(:all)
	end
	
	def new
		@user = User.new
	end

	def edit
		@user = User.find(params[:id])
		@profile = Profile.find(:first,:conditions => { :user_id=>@user.id})
	end


	def create
		@user = User.new(params[:user])
		if @user.save
			@profile = Profile.new
			@profile.user_id = @user.id
			@profile.contact_id = params[:profile][:contact_id]
			@profile.activation_code = ((Time.now.to_f * 10000).round).to_s
			@profile.save
			redirect_to "/administrators/user", :notice => "Registered!"
		else
			render "new"
		end
	end

  def update
    @user = User.find(params[:id])
    
      if @user.update_attributes(params[:user])
      	 @profile = Profile.find(:first,:conditions => { :user_id=>@user.id})
      	 @profile.update_attributes(params[:profile])
         redirect_to "/administrators/user", :notice => 'User was successfully updated.'
      else
        render "edit"
      end
    
  end	

	def delete
		@user = User.find(params[:id])
		@profile = Profile.find(:first,:conditions => { :user_id=>@user.id})
		@user.destroy
		# Delete the profile
		@profile.destroy

		redirect_to "/administrators/user", :notice => "User Deleted"
	end	
end
