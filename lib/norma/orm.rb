#!/usr/bin/env ruby

require 'norma/database'
require 'norma/database_adapter/psql.rb'


module Norma

  EXCLUDE_FIELDS = [ '@as_record' ]

  #

  class ::Class

    def record_store( store=nil )
      @store = store if store
      @store ||= $norma_store
    end

  end

  #

  class ::Object

    def state
      fields = instance_variables - Norma::EXCLUDE_FIELDS
      values = fields.collect { |v| instance_variable_get(v) }
      return fields.zip(values)
    end

    def as_record
      @as_record ||= Norma::Record.new( self )
    end

    def record_id
      as_record.object_id
    end

    #def record_id=( record_id )
    #  as_record.object_id = record_id
    #end

  end

  # Record delegator

  class Record

    def initialize( object )
      @object = object
    end

    def store
      @object.class.record_store
    end

    #def get_id
    #  @object_id ||= store.mint_id
    #end

    def object_id
      @object_id ||= store.mint_id
    end

    #def object_id=( recid )
    #  @object_id = recid
    #end

    # Is the object persisted in the database?

    def persisted? ; @persisted ; end
    def persisted! ; @persisted = true ; end

    # Load

    # Save

    def save
      store.save( @object )
    end

  end

end
