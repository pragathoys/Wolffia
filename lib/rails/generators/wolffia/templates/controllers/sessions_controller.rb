class SessionsController < ApplicationController
	skip_before_filter :require_login, :only => [:new, :create, :destroy]

	def new
	end

	def create
		user = User.find_by_email(params[:email].strip)
		if user && user.authenticate(params[:password].strip)
			session[:user_id] = user.id
			session[:user_role_id] = user.user_role_id
			session[:user_role_level] = UserRole.find( user.user_role_id ).level
			@contact = Contact.find( Profile.find(:first,:conditions=>{:user_id => user.id}).contact_id )
			session[:profile_name] = @contact.name
			
			if session[:user_role_level] == 1 then
				redirect_to "/administrators", :notice => "Logged in!"
			elsif session[:user_role_level] == 11 then
				redirect_to "/curators", :notice => "Logged in!"
			elsif session[:user_role_level] == 21 then
				redirect_to "/submitters", :notice => "Logged in!"				
			elsif session[:user_role_level] == 31 then	
				redirect_to "/registered", :notice => "Logged in!"
			end 			
		else
			session[:user_role_id] = 5
			session[:user_role_level] = 41
			session[:profile_name] = nil
			flash.now.alert = "Invalid email or password"
			render "new"
		end
	end

	def destroy
		session[:user_id] = nil
		session[:user_role_id] = 5
		session[:user_role_level] = 41
		session[:profile_name] = nil
		redirect_to root_url, :notice => "Logged out!"
	end	
end
