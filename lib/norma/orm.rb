#!/usr/bin/env ruby

require 'norma/database'
require 'norma/database_adapter/postgres/adapter.rb'


module Norma

  EXCLUDE_FIELDS = [ '@as_record' ]

  # Record delegator
  class Record

    # Access the delegate object.
    attr :object

    #
    def initialize( object )
      @object = object
    end

    #
    def store
      @object.class.record_store
    end

    #
    def id
      @id ||= store.mint_id
    end

    # Is the object persisted in the database?
    def persisted? ; @persisted ; end
    def persisted! ; @persisted = true ; end

    # Load
    def reload
      store.load(id, @object)
    end

    # Save
    def save
      store.save(@object)
    end

  end

  #
  class ::Class

    # Set the storage adapter for the class.
    # This allows differnt classes to be stored
    # in different databases. By default the 
    # store set in the global $norma_store is
    # used.
    def record_store(store=nil)
      @store = store if store
      @store ||= $norma_store
    end

    def records
      a = []
      ObjectSpace.each_object(self) do |o| ; a << o ; end
      a
    end

  end

  #
  class ::Object

    def as_record
      @as_record ||= Norma::Record.new(self)
    end

    def record_id
      as_record.id
    end

    # TODO: rename to record_state ?
    # TODO: Add user define include/exlcude of persitant variables.
    def state
      fields = instance_variables - Norma::EXCLUDE_FIELDS
      values = fields.collect { |v| instance_variable_get(v) }
      return fields.zip(values)
    end

  end

end

