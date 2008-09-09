
require 'facet/multiton'
require 'facet/enumerable/graph'
require 'facet/hash/keys_to_sym'

require 'rooms/join'


module ROOMS

  # This module tracks all sotes available.
  # It is essentially a hash.

  module Stores

    extend Enumerable

    @registry = {}

    def self.[](k)
      @registry[k.to_sym]
    end

    def self.[]=(k,v)
      @registry[k.to_sym] = v
    end

    def self.register( k, v )
      @registry[k.to_sym] = v
    end

    def self.each( &yld )
      @registry.each( &yld )
    end

  end #Stores

  # Base class for all other stores.

  class Store

    include Multiton

    # Classes that are stored natively.

    FUNDAMENTALS = [ String, Symbol, Numeric, NilClass, TrueClass, FalseClass ]  # JOIN?

    # Classes the cannot be stored.

    EXCLUDES = [ Join, Proc ]

    # (**Expiremental**) Connect to store via a RESTful URI.
    #
    #   Store.open("psql://database=test&host=192.168.0.1&user=jimbo")
    #

    def self.open( uri )
      md = %r{^(\w+):\/\/(.*)}.match( uri )
      if md
        type = md[1]
        path = md[2]
      else
        raise "invalid store uri -- #{uri}"
      end
      config = path.split('&').graph { |e| e.split('=') }
      Stores[type].connect( config )
    end

    # Pass in connection object (whatever it may be.)

    def initialize( connection, logger = nil )
      @connection = connection
      @logger = logger
      @runtime = 0
    end

    # Load a record.

    def load( klass, recid, obj=nil )
      raise InterfaceError, "no load method"
    end

    # Save (or insert) a record.

    def save( klass, obj, recid=nil )
      raise InterfaceError, "no save method"
    end

    # Delete a record.

    def delete( klass, recid )
      raise InterfaceError, "no save method"
    end

    # Select records.

    def select( &block )
      raise InterfaceError, "no select method"
    end

    # Returns next available record index.

    def next_index
      raise InterfaceError, "no next_index method"
    end

    # support methods

    def objectify( data, klass, obj=nil )
      return nil unless data
      datah = {}
      data.each_pair do |k,v|
        if String === v and v[0,2] == "\004\010" #case v when Join
          datah[k] = Join.load(v).read
        else
          datah[k] = v
        end
      end
      obj = klass.allocate unless obj
      obj.assign_with(datah)
      obj
    end

    def datify( obj )
      data = {}
      obj.instance_eval do
        @record_id ||= nil  # make sure this instance var exists
        instance_variables.each do |iv|
          name = iv.sub(/@/, '').to_sym
          data[name] = instance_variable_get(iv)
        end
      end
      data.each do |k,v|
        if EXCLUDES.include?( v.class )
          data[k] = nil  # some things just can't be persisted
        else
          unless FUNDAMENTALS.any? { |c| v.class <= c }
            v.record_save  # TODO if cascading save
            data[k] = Join.new( v ).dump
          end
        end
      end
      data
    end

    # Errors classes.

    class InterfaceError < TypeError ; end

  end #Store

end
