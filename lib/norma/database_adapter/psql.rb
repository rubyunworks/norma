
begin
  require 'postgres'
rescue Object => ex
  puts 'Ruby-PostgreSQL bindings are not installed!'
  #Logger.error 'Ruby-PostgreSQL bindings are not installed!'
  #Logger.error ex
end


module Norma

  # Postgresql Store

  class Database::Psql < Database

    # Create a connection to database.

    def self.connect( config )
      #config.keys_to_sym!

      host     = config[:host]     || "localhost"
      port     = config[:port]     || 5433 unless host.nil?
      username = config[:username] || ""
      password = config[:password] || ""

      if config.has_key?(:database)
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

    # execute sql

    def execute( sql )
#puts "\n#{sql}\n" if $DEBUG
      @connection.exec( sql )
    end

    # Create object link table.

    def up
      sql = <<-END
        CREATE TABLE object (
          id         int,
          klass      text        NOT NULL,
          n          numeric     NULL,
          s          text        NULL,
          t          timestamp   NULL,
          b          bool        NULL,
          a          int[]       NULL,
          PRIMARY KEY (id)
        );
        CREATE SEQUENCE object_sequence;
        CREATE TABLE variable (
          object_id   int    REFERENCES object(id),
          value_id    int    REFERENCES object(id),
          value_name  text   NOT NULL,
          PRIMARY KEY (object_id, value_name)
        );
        CREATE INDEX variable_index ON variable(object_id);
      END
      execute sql
    end

    def down
      sql = <<-END
        DROP INDEX variable_index;
        DROP TABLE variable;
        DROP SEQUENCE object_sequence;
        DROP TABLE object;
      END
      execute sql
    end

    # Mint a new link id.

    def mint_id
      r = execute "SELECT nextval('object_sequence');"
      r[0][0].to_i
    end

    # Save-out an object to the database.

    def save( object )
#puts "Saving a #{object.class} id(#{object.record_id})"
      sql = []
      if object.as_record.persisted?
        sql << Database::Object.new( object ).update_sql
        object.state.each do |field, value|
          value.as_record.save unless value.as_record.persisted?
          sql << Database::Variable.new( object, field, value ).update_sql
        end
      else
        #object.record_id = mint_id
        sql << Database::Object.new( object ).insert_sql
        object.state.each do |field, value|
          value.as_record.save unless value.as_record.persisted?
          sql << Database::Variable.new( object, field, value ).insert_sql
        end
      end
      sql = sql.join("\n")
      execute sql
      object.as_record.persisted!
    end

    # Read-in an object from the database.

    def read( id, object=nil )
      sql = "SELECT * FROM object WHERE id=#{id}"
      res = extecute( sql )
      return nil unless res  # TODO raise error?
      klass = Object.const_get( res.to_h['klass'] )
      object = klass.allocate
      sql = "SELECT * FROM variable WHERE object_id=#{id}"
      res = extecute( sql )
      res.each do |row|
        object.__send__(:instance_variable_set, "@#{row['value_name']}", load( row['value_id'] ) )
      end
      return object
    end

  end

end
