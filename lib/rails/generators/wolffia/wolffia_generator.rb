require 'rubygems'
require "rails/generators"
require 'active_support/core_ext/object/inclusion'
require 'hpricot'

class WolffiaGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)
  argument :command_name, :type => :string, :default => "install"
  class_option :module, :type => :string, :default => "all", :description => "Define which module to install/uninstall. Default value is 'all'."

  def init
    # Read the available modules from the XML file
    xml = File.read(self.class.source_root + '/db_schemas/wolffia_schema.xml')    
    @docxml = Hpricot::XML(xml)
    
    @valid_modules = []

    (@docxml/:modules/:module).each do |module_item|      
      @valid_modules << (module_item.get_attribute :id)
    end
      
    @valid_commands = [ "help" , "list" , "install" , "uninstall" ]  
  end
  
  
  def GeneratorHandler
    command = "#{command_name}".downcase
    module_name = "#{options.module}".downcase

    #Debug
    #puts "Command: #{command}" 
    #puts "Modules: #{module_name}"

    # Check if the command is valid
    if !@valid_commands.include?( command ) then
      puts "The command '#{command}' is not supported by Wolffia gem."
    elsif command=="help" then
      puts "List of available commands:"
      @valid_commands.each do |command|
        puts " - #{command} , e.g. rails g wolffia #{command} [OPTIONS]"
      end
    elsif command=="list" then
      puts "List of available Wolffia plugins:"
      @valid_modules.each do |module_tmp|
        puts " - #{module_tmp}"
      end      
    else
      # Check which module to handle
      if module_name == "all" then
        # create an array with all the modules
        @valid_modules.each do |module_tmp|
          send("#{command.capitalize}Module" , module_tmp )
        end

        send("#{command.capitalize}Admin" )
      else
        # handle the requested and valid module        
        found = false
        @valid_modules.each do |module_tmp|
          if module_tmp == module_name then
            found = true
            break
          end
        end

        if found then
          send("#{command.capitalize}Module" , module_name )
        else
          # Check if requested to install/unistall the admin
          if module_name == "admin"  then
            send("#{command.capitalize}Admin")
          else
            puts "The module '#{module_name}' is not supported by Wolffia gem."
          end
        end

      end
    end   
  end

  private
  def InstallModule(module_name)
    puts "Installing the #{module_name.capitalize} Plugin"

    # Loop through the tables of this module
    (@docxml/:modules/:module/"##{module_name}"/:tables/:table ).each do |table_item|
      @table_name = table_item.get_attribute :id
      @table_key  = table_item.get_attribute :primary_key
      @class_name = @table_name.camelize

      # parse the fields of the table & the ORM relations
      @column_items = ""
      @field_items = ""
      @orm_items = ""
      (table_item/:fields/:field ).each do |field_item|
        field_item_id = (field_item.get_attribute :id)
        if @column_items == "" then
          @column_items = ":#{field_item_id}"
        else
          @column_items = @column_items + ", :#{field_item_id}"
        end
        @field_items = @field_items + "\t\tt." + (field_item.get_attribute :type) + " :" + field_item_id
        if (field_item.get_attribute :not_null) == "1" then
          @field_items = @field_items + ",\t :null=> false"
        end
        if (field_item.get_attribute :default) != "" then
          @field_items = @field_items + ",\t :default=> " + (field_item.get_attribute :default)
        end

        @field_items = @field_items + "\n"

        foreign_key = (field_item.get_attribute :foreign_key)        
        if foreign_key != nil && !foreign_key.empty? then
          foreign_key_class = foreign_key.camelize
          @orm_items = @orm_items + "\t\tbelongs_to :#{foreign_key}, :class_name => \'#{foreign_key_class}\', :foreign_key => :#{field_item_id}\n"
        end

      end
      #--------------

      #parse the indexes
      @index_items = ""
      @constraint_items = ""
      # counters for auto naming
      @unique_id = 1
      @index_id = 1

      (table_item/:indexes/:index ).each do |index_item|
         
        
        #grab the columns from the XML
        @columns = (index_item.get_attribute :columns).split(",")
        @comun_names = ""
        @columns.each do |column|
          if @comun_names == "" then
            @comun_names = "\"#{column}\""
          else
            @comun_names = @comun_names + ", \"#{column}\""
          end
        end

        #+ (index_item.get_attribute :type) + " :" + (index_item.get_attribute :id)
        if (index_item.get_attribute :unique) == "1" then
          @constraint_items = @constraint_items + "\t\tsuppress_messages {execute \'alter table #{@table_name}  add constraint #{@table_name}_c#{@unique_id}  unique("
          @constraint_items = @constraint_items + @comun_names
          @constraint_items = @constraint_items + ")\'"
          @constraint_items = @constraint_items + "}\n"
          @constraint_items = @constraint_items + "\t\tsay \"Constraint for columns \'"+ (index_item.get_attribute :columns) + "\' created!\"\n"
          
          @unique_id = @unique_id + 1
        else
          @index_items = @index_items + "\t\tsuppress_messages {add_index \"#{@table_name}\", ["
          @index_items = @index_items + @comun_names
          @index_items = @index_items + "], :name=> \"#{@table_name}_idx#{@index_id}\""
          @index_items = @index_items + "}\n"
          @index_items = @index_items + "\t\tsay \"Index for columns \'"+ (index_item.get_attribute :columns) + "\' created!\"\n"

          @index_id = @index_id + 1
        end

      end
      #--------------      

      template "models/generic_model.erb", "app/models/#{@table_name}.rb"
      template "migrations/generic_migration_create.erb", "db/migrate/" + ((Time.now.to_f * 10000).round).to_s + "_create_#{@table_name}.rb"
    end

  end

  private
  def UninstallModule(module_name)
    puts "Uninstalling the #{module_name.capitalize} Module"

    # Loop through the tables of this module
    (@docxml/:modules/:module/"##{module_name}"/:tables/:table ).each do |table_item|
      table_name = (table_item.get_attribute :id).camelize

      Rails::Generators.invoke "model", ["#{table_name}"], :behavior => :revoke, :destination_root => Rails.root
      Rails::Generators.invoke "migration", ["Create#{table_name}"], :behavior => :revoke, :destination_root => Rails.root
    end

  end

  private 
  def InstallAdmin()
    puts "Installing Basic Admin for Wolffia"

    # Copy wolffiacp
    copy_file "controllers/wolffiacp_controller.rb", "app/controllers/wolffiacp_controller.rb"    
    copy_file "views/wolffiacp/index.html.erb", "app/views/wolffiacp/index.html.erb"   
    copy_file "views/wolffiacp/install.html.erb", "app/views/wolffiacp/install.html.erb"

    copy_file "controllers/posts_controller.rb", "app/controllers/posts_controller.rb"    
    copy_file "controllers/blogs_controller.rb", "app/controllers/blogs_controller.rb"    
    copy_file "controllers/comments_controller.rb", "app/controllers/comments_controller.rb"    


    # Copy Pages
    copy_file "controllers/pages_controller.rb", "app/controllers/pages_controller.rb"    
    copy_file "views/pages/index.html.erb", "app/views/pages/index.html.erb"    
    copy_file "views/pages/new.html.erb", "app/views/pages/new.html.erb"   
    copy_file "views/pages/edit.html.erb", "app/views/pages/edit.html.erb"    
    copy_file "views/pages/show.html.erb", "app/views/pages/show.html.erb"    
    copy_file "views/pages/_form.html.erb", "app/views/pages/_form.html.erb"   

    # Copy sessions
    copy_file "controllers/sessions_controller.rb", "app/controllers/sessions_controller.rb"    
    copy_file "views/sessions/new.html.erb", "app/views/sessions/new.html.erb"   

    # Copy static
    copy_file "controllers/static_controller.rb", "app/controllers/static_controller.rb"    
    copy_file "views/static/index.html.erb", "app/views/static/index.html.erb"   

    # Copy user Admin
    copy_file "controllers/user_controller.rb", "app/controllers/user_controller.rb"    
    copy_file "views/user/index.html.erb", "app/views/user/index.html.erb"    
    copy_file "views/user/new.html.erb", "app/views/user/new.html.erb"   
    copy_file "views/user/edit.html.erb", "app/views/user/edit.html.erb"    
    copy_file "views/user/show.html.erb", "app/views/user/show.html.erb"    
    copy_file "views/user/_form.html.erb", "app/views/user/_form.html.erb"   

    # Copy CSS
    copy_file "assets/stylesheets/wolffia.css", "app/assets/stylesheets/wolffia.css"  
    copy_file "assets/stylesheets/unsemantic-grid-responsive.css", "app/assets/stylesheets/unsemantic-grid-responsive.css"  

    # layout
    copy_file "views/layouts/wolffiacp.html.erb", "app/views/layouts/wolffiacp.html.erb"  

    # Copy JS
    copy_file "assets/javascripts/wolffia.js", "app/assets/javascripts/wolffia.js"    

    # Add Route
    route "resources :wolffiacp"
    route "resources :pages"
    route "resources :users"
    route "resources :sessions"
    route "resources :static"
    route "resources :posts"
    route "resources :blogs"
    route "resources :comments"

    route "root :to => 'static#index'"

    # remove the public/index.html
    remove_file("public/index.html") 
  end

  private 
  def UninstallAdmin()
    puts "Uninstalling Basic Admin for Wolffia"

      remove_file("app/controllers/wolffiacp_controller.rb")
      remove_file("app/views/wolffiacp/index.html.erb") 
      remove_file("app/views/wolffiacp/install.html.erb") 
      remove_file("app/views/wolffiacp")
      gsub_file "config/routes.rb" , "resources :wolffiacp" , ""

      remove_file("app/controllers/static_controller.rb")
      remove_file("app/views/static/index.html.erb") 
      remove_file("app/views/static")
      gsub_file "config/routes.rb" , "resources :static" , ""

      remove_file("app/controllers/sessions_controller.rb")
      remove_file("app/views/sessions/new.html.erb") 
      remove_file("app/views/sessions")
      gsub_file "config/routes.rb" , "resources :sessions" , ""

      remove_file("app/controllers/pages_controller.rb")
      remove_file("app/views/pages/index.html.erb") 
      remove_file("app/views/pages/new.html.erb") 
      remove_file("app/views/pages/edit.html.erb") 
      remove_file("app/views/pages/show.html.erb") 
      remove_file("app/views/pages/_form.html.erb") 
      remove_file("app/views/pages")
      gsub_file "config/routes.rb" , "resources :pages" , ""

      remove_file("app/controllers/user_controller.rb")
      remove_file("app/views/user/index.html.erb") 
      remove_file("app/views/user/new.html.erb") 
      remove_file("app/views/user/edit.html.erb") 
      remove_file("app/views/user/show.html.erb") 
      remove_file("app/views/user/_form.html.erb") 
      remove_file("app/views/user")
      gsub_file "config/routes.rb" , "resources :users" , ""

      # layout
      remove_file("app/views/layouts/wolffiacp.html.erb")

      remove_file("app/assets/stylesheets/wolffia.css")
      remove_file("app/assets/stylesheets/unsemantic-grid-responsive.css")

      remove_file("app/assets/javascripts/wolffia.js")

      gsub_file "config/routes.rb" , "root :to => 'static#index'" , ""

      gsub_file "config/routes.rb" , "resources :blogs" , ""
      gsub_file "config/routes.rb" , "resources :posts" , ""
      gsub_file "config/routes.rb" , "resources :comments" , ""

      # put back the index file
      copy_file "views/public/index.html", "public/index.html"   

  end

end
