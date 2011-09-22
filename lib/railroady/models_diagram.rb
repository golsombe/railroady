# RailRoady - RoR diagrams generator
# http://railroad.rubyforge.org
#
# Copyright 2007-2008 - Javier Smaldone (http://www.smaldone.com.ar)
# See COPYING for more details

require 'railroady/app_diagram'

# RailRoady models diagram
class ModelsDiagram < AppDiagram

  def initialize(options = OptionsStruct.new)
    #options.exclude.map! {|e| "app/models/" + e}
    super options 
    @graph.diagram_type = 'Models'
    # Processed habtm associations
    @habtm = []
  end

  # Process model files
  def generate
    STDERR.print "Generating models diagram\n" if @options.verbose
    get_files.each do |f|
    begin
	text = File.read(f)
	mt = ""
	if text.include? "ActiveRecord::Base" then
		mt = "AR"
		process_class extract_class_name(f).constantize, mt
		STDERR.print "\t\tYou're using ActiveRecord models\n"
	elsif text.include? "MongoMapper::Document" then
		mt = "MM"
		STDERR.print "\t\tYou're using MongoMapper models\n"
		process_class extract_class_name(f).constantize, mt
	else
		mt = "AR"
		STDERR.print "\t\tCould not determine your ORM, using default\n"
		process_class extract_class_name(f).constantize, mt
	end        
      rescue Exception
        STDERR.print "Warning: exception #{$!} raised while trying to load model class #{f}\n"
      end #begin / rescue
    end #get_files.each
  end #def generate
      begin
        process_class extract_class_name(f).constantize
      rescue Exception
        STDERR.print "Warning: exception #{$!} raised while trying to load model class #{f}\n"
      end

    end
  end 

  def get_files(prefix ='')
    files = !@options.specify.empty? ? Dir.glob(@options.specify) : Dir.glob(prefix << "app/models/**/*.rb")
    files += Dir.glob("vendor/plugins/**/app/models/*.rb") if @options.plugins_models
    files -= Dir.glob(@options.exclude)
    files

  end #get_files

  # Process a model class
  def process_class(current_class, model_type)

	STDERR.print "\tProcessing #{current_class}\n" if @options.verbose
	magic_fields = [
	"created_at", "created_on", "updated_at", "updated_on",
	"lock_version", "type", "id", "position", "parent_id", "lft", 
	"rgt", "quote", "template"
	]

	generated = false
	node_attribs = []
	if @options.brief 
		#|| current_class.abstract_class?
		node_type = 'model-brief'
	else 
		node_type = 'model'
	end #@options.brief || current_class.abstract_class?
     
    # Is current_clas derived from ActiveRecord::Base?
    if current_class.respond_to?'reflect_on_all_associations'
	STDERR.print "\tActiveRecord #{current_class}\n" if @options.verbose
      #~ node_attribs = []

  end

  # Process a model class
  def process_class(current_class)

    STDERR.print "\tProcessing #{current_class}\n" if @options.verbose

    generated = false
        
    # Is current_clas derived from ActiveRecord::Base?
    if current_class.respond_to?'reflect_on_all_associations'


      node_attribs = []

      if @options.brief || current_class.abstract_class?
        node_type = 'model-brief'
      else 
        node_type = 'model'

        # Collect model's content columns

        content_columns = current_class.content_columns
	
        if @options.hide_magic 
          # From patch #13351
          # http://wiki.rubyonrails.org/rails/pages/MagicFieldNames


          magic_fields = [
          "created_at", "created_on", "updated_at", "updated_on",
          "lock_version", "type", "id", "position", "parent_id", "lft", 
          "rgt", "quote", "template"
          ]

          magic_fields << current_class.table_name + "_count" if current_class.respond_to? 'table_name' 
          content_columns = current_class.content_columns.select {|c| ! magic_fields.include? c.name}
        else
          content_columns = current_class.content_columns

        end #@options.hide_magic

	content_columns.each do |a|
          content_column = a.name
          content_column += ' :' + a.type.to_s unless @options.hide_types
          node_attribs << content_column
        end #content_columns.each
     end

        end
        
        content_columns.each do |a|
          content_column = a.name
          content_column += ' :' + a.type.to_s unless @options.hide_types
          node_attribs << content_column
        end
      end

      @graph.add_node [node_type, current_class.name, node_attribs]
      generated = true
      # Process class associations
      associations = current_class.reflect_on_all_associations
      if @options.inheritance && ! @options.transitive
        superclass_associations = current_class.superclass.reflect_on_all_associations

        associations = associations.select{|a| ! superclass_associations.include? a} 
        # This doesn't works!
        # associations -= current_class.superclass.reflect_on_all_associations
      end #@options.inheritance && @optins.transitive
		associations.each do |a|
			process_association current_class.name, a
		end # associations.each
    elsif @options.all && (current_class.is_a? Class)
      # Not ActiveRecord::Base model
      STDERR.print "\tNot AR: I made it past the elseif" if @options.verbose

        
        associations = associations.select{|a| ! superclass_associations.include? a} 
        # This doesn't works!
        # associations -= current_class.superclass.reflect_on_all_associations
      end
      associations.each do |a|
        process_association current_class.name, a
      end
    elsif @options.all && (current_class.is_a? Class)
      # Not ActiveRecord::Base model

      node_type = @options.brief ? 'class-brief' : 'class'
      @graph.add_node [node_type, current_class.name]
      generated = true
    elsif @options.modules && (current_class.is_a? Module)

	STDERR.print "\tJust a base class, need to add fields" if @options.verbose   
        @graph.add_node ['module', current_class.name]
    end #current_class.respond_to?'reflect_on_all_associations'


#Catching the MongoMapper classes
    if model_type == "MM" 
	     node_attribs = []
	               magic_fields = [
          "created_at", "created_on", "updated_at", "updated_on",
          "lock_version", "type", "id", "position", "parent_id", "lft", 
          "rgt", "quote", "template","_id"
          ]
	 STDERR.print "In the MongoMapper Processor" if @options.verbose
	current_class.keys.each do |k|
			key_include = magic_fields.include? k[1].name
		    if  key_include == false
			 #STDERR.print "Key: " + k[1].name + " "+ (magic_fields.include? ! k[1].name).to_s + "\n" if @options.verbose   
			content_column = k[1].name
			content_column += " :" + k[1].type.to_s unless @options.hide_types
			node_attribs << content_column
		    end #magic_fields
	    end # keys
	    @graph.add_node [node_type, current_class.name, node_attribs]
	    generated = true
		current_class.associations.each do |a|
			case a[1].class.to_s
				when "MongoMapper::Plugins::Associations::BelongsToAssociation"
					assoc_type = "one-one"
				when "MongoMapper::Plugins::Associations::ManyAssociation"
					assoc_type = "one-many"
				else
					assoc_type = "is-a" 
				end
			class_name = current_class.name
			assoc_class_name = a[1].class_name
			assoc_name = class_name + "_" + assoc_class_name
			
			return if a[1].class.to_s == "MongoMapper::Plugins::Associations::BelongsToAssociation" && !@options.show_belongs_to
			

			@graph.add_edge [assoc_type, class_name, assoc_class_name, ""]    	
		end
	    

end #model_name
	


        @graph.add_node ['module', current_class.name]
    end


    # Only consider meaningful inheritance relations for generated classes
    if @options.inheritance && generated && 
       (current_class.superclass != ActiveRecord::Base) &&
       (current_class.superclass != Object)
      @graph.add_edge ['is-a', current_class.superclass.name, current_class.name]
    end      

  end # process_class

  # Process a model association
  def process_association(class_name, assoc)

    STDERR.print "\t\tProcessing model association #{assoc.name.to_s}\n" if @options.verbose

    # Skip "belongs_to" associations
    return if assoc.macro.to_s == 'belongs_to' && !@options.show_belongs_to

    # Only non standard association names needs a label
    
    # from patch #12384
    # if assoc.class_name == assoc.name.to_s.singularize.camelize
    assoc_class_name = (assoc.class_name.respond_to? 'underscore') ? assoc.class_name.underscore.singularize.camelize : assoc.class_name 
    if assoc_class_name == assoc.name.to_s.singularize.camelize
      assoc_name = ''
    else
      assoc_name = assoc.name.to_s
    end 

    # Patch from "alpack" to support classes in a non-root module namespace. See: http://disq.us/yxl1v
    if class_name.include?("::") && !assoc_class_name.include?("::")
      assoc_class_name = class_name.split("::")[0..-2].push(assoc_class_name).join("::")
    end
    assoc_class_name.gsub!(%r{^::}, '')

    if ['has_one', 'belongs_to'].include? assoc.macro.to_s
      assoc_type = 'one-one'
    elsif assoc.macro.to_s == 'has_many' && (! assoc.options[:through])
      assoc_type = 'one-many'
    else # habtm or has_many, :through
      return if @habtm.include? [assoc.class_name, class_name, assoc_name]
      assoc_type = 'many-many'
      @habtm << [class_name, assoc.class_name, assoc_name]
    end  
    # from patch #12384    
    # @graph.add_edge [assoc_type, class_name, assoc.class_name, assoc_name]
    @graph.add_edge [assoc_type, class_name, assoc_class_name, assoc_name]    
  end # process_association

end # class ModelsDiagram
