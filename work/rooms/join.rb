# Object Oriented Record Management System

module ROOMS

  class Join

    def initialize( object )
      @store_uri = object.record_store.uri
      @record_id = object.record_id
    end

    def read
      Store.load( @store_uri ).get( @record_id )
    end

    def dump
      Marhsal.dump(self)
    end

    # stream alwasy starts with \004\010 ?
    def load( stream )
      Marhsal.load( stream )
    end

  end

end
