require 'rubygems'
require "rails/generators"
require 'active_support/core_ext/object/inclusion'
require 'hpricot'

class RorchadoGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)
  argument :command_name, :type => :string, :default => "install"
  class_option :module, :type => :string, :default => "all", :description => "Define which module to install/uninstall. Default value is 'all'."

  def init
    # Read the available modules from the XML file
    xml = File.read(self.class.source_root + '/db_schemas/chado_schema.xml')    
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
    # Copy Cv Admin
    copy_file "controllers/cv_controller.rb", "app/controllers/cv_controller.rb"    
    copy_file "views/cv/index.html.erb", "app/views/cv/index.html.erb"    
    copy_file "views/cv/new.html.erb", "app/views/cv/new.html.erb"   
    copy_file "views/cv/edit.html.erb", "app/views/cv/edit.html.erb"    
    copy_file "views/cv/show.html.erb", "app/views/cv/show.html.erb"    
    copy_file "views/cv/_form.html.erb", "app/views/cv/_form.html.erb"   
    copy_file "controllers/cvterm_controller.rb", "app/controllers/cvterm_controller.rb"    
    copy_file "views/cvterm/index.html.erb", "app/views/cvterm/index.html.erb"    
    copy_file "views/cvterm/new.html.erb", "app/views/cvterm/new.html.erb"   
    copy_file "views/cvterm/edit.html.erb", "app/views/cvterm/edit.html.erb"    
    copy_file "views/cvterm/show.html.erb", "app/views/cvterm/show.html.erb"    
    copy_file "views/cvterm/_form.html.erb", "app/views/cvterm/_form.html.erb"   

    # Copy Contact Admin
    copy_file "controllers/contact_controller.rb", "app/controllers/contact_controller.rb"    
    copy_file "views/contact/index.html.erb", "app/views/contact/index.html.erb"    
    copy_file "views/contact/new.html.erb", "app/views/contact/new.html.erb"   
    copy_file "views/contact/edit.html.erb", "app/views/contact/edit.html.erb"    
    copy_file "views/contact/show.html.erb", "app/views/contact/show.html.erb"    
    copy_file "views/contact/_form.html.erb", "app/views/contact/_form.html.erb"   

    # Copy Stock Admin
    copy_file "controllers/stock_controller.rb", "app/controllers/stock_controller.rb"    
    copy_file "views/stock/index.html.erb", "app/views/stock/index.html.erb"    
    copy_file "views/stock/new.html.erb", "app/views/stock/new.html.erb"   
    copy_file "views/stock/edit.html.erb", "app/views/stock/edit.html.erb"    
    copy_file "views/stock/show.html.erb", "app/views/stock/show.html.erb"    
    copy_file "views/stock/_form.html.erb", "app/views/stock/_form.html.erb"   

    # Add Route
    route "resources :wolffiacp"
    route "resources :pages"
    route "resources :users"
    route "resources :sessions"
  end

  private 
  def UninstallAdmin()
    puts "Uninstalling Basic Admin for Wolffia"

      remove_file("app/controllers/cvterm_controller.rb")
      remove_file("app/views/cvterm/index.html.erb") 
      remove_file("app/views/cvterm/new.html.erb") 
      remove_file("app/views/cvterm/edit.html.erb") 
      remove_file("app/views/cvterm/show.html.erb") 
      remove_file("app/views/cvterm/_form.html.erb") 
      gsub_file "config/routes.rb" , "resources :wolffiacp" , ""

      remove_file("app/controllers/cv_controller.rb")
      remove_file("app/views/cv/index.html.erb") 
      remove_file("app/views/cv/new.html.erb") 
      remove_file("app/views/cv/edit.html.erb") 
      remove_file("app/views/cv/show.html.erb") 
      remove_file("app/views/cv/_form.html.erb") 
      gsub_file "config/routes.rb" , "resources :cv" , ""

      remove_file("app/controllers/contact_controller.rb")
      remove_file("app/views/contact/index.html.erb") 
      remove_file("app/views/contact/new.html.erb") 
      remove_file("app/views/contact/edit.html.erb") 
      remove_file("app/views/contact/show.html.erb") 
      remove_file("app/views/contact/_form.html.erb") 
      gsub_file "config/routes.rb" , "resources :contact" , ""

      remove_file("app/controllers/stock_controller.rb")
      remove_file("app/views/stock/index.html.erb") 
      remove_file("app/views/stock/new.html.erb") 
      remove_file("app/views/stock/edit.html.erb") 
      remove_file("app/views/stock/show.html.erb") 
      remove_file("app/views/stock/_form.html.erb") 
      gsub_file "config/routes.rb" , "resources :stock" , ""      
  end

end
