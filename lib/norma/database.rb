
module Norma

  #

  class Database

    def initialize( connection, logger = nil )
      @connection = connection
      @logger = logger
      @runtime = 0
      @cache = {}
    end

    # Load a record.

    def load( id, object=nil )
      @cache[ id ] ||= load( id )
    end

    # Read a record.

    def read( id, object=nil )
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

  end

  # Database Interface Error class

  class Database::InterfaceError < TypeError ; end


  # Object Table

  class Database::Object

    # Pass in connection object (whatever it may be.)

    def initialize( object )
      set( object )
    end

    def set( object )
      clear

      @id     = object.record_id
      @klass  = object.class

      case object
      when Numeric
        @n = object
      when String, Symbol
        @s = %{"#{object}"}
      when Time #, Date
        @t = '"' + object.strftime('%Y-%m-%d %H:%M:%S') + '"'
      when TrueClass, FalseClass
        @b = (object ? 'TRUE' : 'FALSE')
      when Array
        @a = "'{" + object.collect { |o| "#{o.record_id}" }.join(',') + "}'"
      when Hash
        @a = "'{" + object.collect { |k,v| %{#{k.record_id},#{v.record_id}} }.join(',') + "}'"
      #else
      end

      self
    end

    def clear
      @n, @s, @t, @b, @a = *(['NULL']*5)
    end

    def update_sql
      sql = ''
      sql << %|UPDATE object\n|
      sql << %|SET klass='#{@klass}', n=#{@n}, s=#{@s}, t=#{@t}, b=#{@b}, a=#{@a}\n|
      sql << %|WHERE id=#{@id}|
      sql << ';'
    end

    def insert_sql
      sql = ''
      sql << %|INSERT INTO object |
      sql << %|(id, klass, n, s, t, b, a)\n|
      sql << %|VALUES (#{@id}, '#{@klass}', #{@n}, #{@s}, #{@t}, #{@b}, #{@a})|
      sql << ';'
    end

  end

  # Variable Table

  class Database::Variable

    # Pass in connection object (whatever it may be.)

    def initialize( object, field, value )
      set( object, field, value )
    end

    def set( object, field, value )
      @object_id  = object.record_id
      @value_id   = value.record_id #'NULL'
      @value_name = field.sub(/^@/,'')
      self
    end

    def update_sql
      sql = ''
      sql << %|UPDATE variable\n|
      sql << %|SET value_id=#{@value_id}\n|
      sql << %|WHERE object_id=#{@object_id} AND value_name='#{@value_name}'|
      sql << ';'
    end

    def insert_sql
      sql = ''
      sql << %|INSERT INTO variable |
      sql << %|(object_id, value_id, value_name)\n|
      sql << %|VALUES (#{@object_id}, #{@value_id}, '#{@value_name}')|
      sql << ';'
    end

  end

end
