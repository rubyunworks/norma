# builder.rb

module Recordable

  # This module provides methods to automagically build-out a class from database information
  # It is intended as a class method
  
  module ClassBuilder
  
    def build_class(*overwrite)
      # pluralization issue
      tbl = respond_to?(:table) ? self.table : self.name.downcase
      
      connection.columns(tbl).each { |c|
        # c has name, default and type
        if self.public_instance_methods(true).include?(c.name) and (! overwrite.include?(c.name))
          warn "Will not create reader for method ##{c.name}. " +
               "It already exists and was not specified in the overwrite list." #if $DEBUG
        else
          class_eval <<-EOS
            def #{c.name}
              @#{c.name}
            end
          EOS
        end
        if self.public_instance_methods(true).include?("#{c.name}=") and (! overwrite.include?(c.name))
          warn "Will not create writer for method ##{c.name}. " +
               "It already exists and was not specifiec in the overwrite list." #if $DEBUG
        else
          class_eval <<-EOS
            def #{c.name}=(v)
              @#{c.name} = v
            end
          EOS
        end
      }
    end
    
  end  # ClassBuilder
  
end  # Recordable
