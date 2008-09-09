# Object-Oriented Record Management System

require 'facets'
require 'facet/kernel/require_all'
require 'facet/kernel/assign_with'
require 'facet/kernel/assign_from'
require 'facet/string/methodize'

require 'rooms/join'
require_all 'rooms/store/*'

# You may wonder why the heck we're using tow lambda's here
# rather than modules. Well, since the "powers that be"
# refuse to allow Ruby to have a to include a module's
# instance level while extending with it's class level
# at the same time, this is best way do it. It avoids an ungly
# hack of adding two modules into the inheritence chain with
# stupid names like ROOMS::ClassMethods and ROOMS::ObjectMethods.

module ROOMS

  CLASS_METHODS = lambda do

    def record_table
      name.methodize
    end

    def record_load( recid )
      record_store.load( self, recid )
    end

    def record_select( &block )
      record_store.select( self, &block )
    end

    def record_delete( recid )
      record_store.delete( self, recid )
    end

  end

  OBJECT_METHODS = lambda do

    attr_accessor :record_id

    def record_store
      self.class.record_store  # TODO what about per-object class?
    end

    def record_save
      @record_id = record_store.save( self.class, self, @record_id )
    end

    def record_load
      record_store.load( self.class, @record_id, self )
    end

    def record_delete
      record_store.delete( self.record_id )
    end

  end

end


class Class

  def record_primer( obj=nil )
    if obj
      case obj
      when Hash
        @record_primer = self.allocate.assign_with( obj )
      else
        @record_primer = self.allocate.assign_from( obj )
      end
    end
    @record_primer
  end

  # TODO maybe better name than "store"?

  def record_store( store=nil )
    if store
      raise TypeError unless ROOMS::Store === store
      @record_store = store
      self.class_eval &ROOMS::OBJECT_METHODS
      self.instance_eval &ROOMS::CLASS_METHODS
      store.create( self, record_primer )
    end
    @record_store
  end

end


#class Object
#end
