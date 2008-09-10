
begin
  require 'postgres'
rescue Object => ex
  puts 'Ruby-PostgreSQL bindings are not installed!'
  #Logger.error 'Ruby-PostgreSQL bindings are not installed!'
  #Logger.error ex
end


module Norma

  # Postgresql Store
  class Database::Postgres < Database

    # Create a connection to database.
    def self.connect(config)
      host     = config[:host]     || "localhost"
      port     = config[:port]     || 5433 unless host.nil?
      username = config[:username] || ""
      password = config[:password] || ""

      if config.key?(:database)
        database = config[:database]
      else
        raise ArgumentError, "No database specified. Missing argument: database."
      end

      return new(
        PGconn.connect(host, port, "", "", database, username, password) #, logger
      )
    end

    # Return database conguration.
    def config
      { :database => @connection.db,
        :port => @connection.port,
        :host => @connection.host,
        :username => @connection.user
      }
    end

    # Execute SQL
    def execute(sql)
      #puts "\n#{sql}\n" if $DEBUG
      @connection.exec(sql)
    end

    # Create object link tables.
    def up
      file = File.join(File.dirname(__FILE__), 'up.sql')
      sql  = File.read(file)
      execute sql
    end

    # Destroy object link tables.
    def down
      file = File.join(File.dirname(__FILE__), 'down.sql')
      sql  = File.read(file)
      execute sql
    end

    def bootstrap
      sql = "SELECT id FROM obj;"
      res = execute(sql)
      res.each do |row|
        load(row['id'])
      end
    end

    # Get a new object id.
    def mint_id
      r = execute "SELECT nextval('obj_sequence');"
      r[0][0].to_i
    end

    # Save-out an object to the database.
    def save(object)
#puts "Saving a #{object.class} id(#{object.record_id})"
      sql = []
      if object.as_record.persisted?
        sql << update_sql(object)
        object.state.each do |field, value|
          value.as_record.save unless value.as_record.persisted?
          sql << update_ivar_sql(object, field, value)
        end
      else
        sql << insert_sql(object)
        object.state.each do |field, value|
          value.as_record.save unless value.as_record.persisted?
          sql << insert_ivar_sql(object, field, value)
        end
      end
      sql = sql.join("\n")
      execute(sql)
      object.as_record.persisted!
    end

    # TODO: Use a join query if possible and if more efficient.
    def read(id, object=nil)
      sql = "SELECT * FROM obj WHERE id=#{id};"
      obj = execute(sql)

      # THINK: raise error instead?
      return nil unless obj

      classname = obj[0][1]
      klass = Object.const_get(classname)

      immutable = (klass<=Fixnum || klass<=Symbol)

      if CORE.include?(klass)
        sql = "SELECT * FROM obj#{klass} WHERE id=#{id};"
        rec = execute(sql)
        object = __send__("new#{klass}", rec[0])
      else
        object = klass.allocate
      end

      unless immutable
        sql = "SELECT * FROM ivar WHERE obj_id=#{id};"
        var = execute(sql)
        var.each do |row|
          object.__send__(:instance_variable_set, "@#{row['name']}", load(row['val_id']))
        end
      end

      object
    end
 
  end # class Database::Postgres

end # module Norma

