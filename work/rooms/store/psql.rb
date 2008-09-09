
require 'facet/hash/keys_to_sym'
require 'facet/string/pathize'

require 'facets/more/recorder'  # CHANGE!

require 'rooms/store'

begin
  require 'postgres'
rescue Object => ex
  puts 'Ruby-PostgreSQL bindings are not installed!'
  #Logger.error 'Ruby-PostgreSQL bindings are not installed!'
  #Logger.error ex
end

module ROOMS

  class PsqlStore < Store

    def self.connect( config )
      config.keys_to_sym!

      host     = config[:host]     || "localhost"
      port     = config[:port]     || 5433 unless host.nil?
      username = config[:username] || ""
      password = config[:password] || ""

      if config.has_key?(:database)
        database = config[:database]
      else
        raise ArgumentError, "No database specified. Missing argument: database."
      end

      return self.new(
        PGconn.connect(host, port, "", "", database, username, password) #, logger
      )
    end

    def config
      { :database => @connection.db,
        :port => @connection.port,
        :host => @connection.host,
        :username => @connection.user
      }
    end

    def uri
      opts = config.collect{ |k,v| "#{k}=#{v}" }
      "psql://#{opts.join('&')}"
    end

    # table methods
    # TODO wrap in single transaction

    def create( klass, primer_obj )
      # make sure table doesn't already exist.
      return if table?( klass.record_table )
      #
      if klass.respond_to?(:sql_create_table)
        result = execute( klass.sql_create_table )
        # TODO make sure table got created
      else
        sql = "CREATE TABLE #{klass.record_table}"
        sql << " ( record_id SERIAL PRIMARY KEY );"
        result = execute( sql )
        data = datify( primer_obj )
        data.delete( :record_id )  # don't re-create the record_id
        data.each do |k,v|
          sql = add_column( klass.record_table, k, v )
          result = execute( sql )
        end
      end
    end

    #

    def execute( sql )
p sql  # if $DEBUG
      @connection.exec( sql )
    end

    # TODO need a more robust way to do this.

    def table?( table_name )
      sql = "SELECT record_id FROM #{table_name};"
      begin
        result = execute( sql )
      rescue PGError
        return false
      end
      true
    end
    private :table?

    def drop( klass )
      sql = "DROP TABLE #{klass.record_table};"
      result = execute( sql )
    end

    # record methods

    def load( klass, recid, obj=nil )
      sql = "SELECT * FROM #{klass.record_table} WHERE record_id=#{recid};"
      result = execucte( sql )
      return nil if result.num_tuples == 0
      data = result[0].to_hash
      objectify( data, klass, obj )
    end

    def save( klass, obj, recid=nil )
      data = datify( obj )
      data.delete( :record_id )  # TODO use this for recid instead of parameter!
      if recid
        set = data.collect{ |k,v| "#{k} = #{quote(v)}" }.join(',');
        sql = "UPDATE #{klass.record_table} SET #{set} WHERE record_id=#{recid};"
      else
        cols = [] ; vals = []
        data.each { |k,v| cols << k ; vals << quote(v) }
        cols = cols.join(',') ; vals = vals.join(',')
        sql = "INSERT INTO #{klass.record_table} (#{cols}) VALUES (#{vals});"
      end
      result = execute( sql )
      # need to get new record_id and set the instance var
    end


    def save( klass, obj, recid=nil )
      # Datification
      data = datify( obj )
      data.delete( :record_id )  # TODO use this for recid instead of parameter!
      # Dynamics
      data.each do |column, value|
        unless klass.record_column( column ).type == value.class
          if klass.record_ == :dynamic
            sql_modify_column( klass.record_table, column, to )
          else  # :static
            value  # try to convert type
          end
        end
      end
      # Save Record
      if recid
        set = data.collect{ |k,v| "#{k} = #{quote(v)}" }.join(',');
        sql = "UPDATE #{klass.record_table} SET #{set} WHERE record_id=#{recid};"
      else
        cols = [] ; vals = []
        data.each { |k,v| cols << k ; vals << quote(v) }
        cols = cols.join(',') ; vals = vals.join(',')
        sql = "INSERT INTO #{klass.record_table} (#{cols}) VALUES (#{vals});"
      end
      result = execute( sql )
      # need to get new record_id and set the instance var
    end


    def delete( klass, recid=nil )
      sql = "DELETE FROM #{klass.record_table} WHERE record_id=#{recid};"
      result = execute( sql )
    end

    def select( klass, &block )
      where = recorder_to_where( block.call( Recorder.new ) )
      sql = "SELECT * FROM #{klass.record_table} WHERE #{where};"
      result = execute( sql )
# TODO how to handle a recordset?
    end

    #def next_index( klass )
    #  sql = "SELECT record_id FROM #{klass.record_table}"
    #  result = execute( sql )
    #  result.collect { |r| r[0] }
    #end

    def count( klass )
      sql = "SELECT COUNT(*) FROM #{klass.record_table}"
      result = execute( sql )
      result[0][0]
    end

  private

    def recorder_to_where( recorder )
      wp = WherePlayer.new( self )
      recorder.__replay__( wp )
    end

    def quote( obj ) #, column = nil)
      case obj
      when String  # (for ruby-mode)
        "'" << obj.gsub( %r{\\},'\&\&' ).gsub(%r{'}, %{''}) << "'"
      when NilClass
        "NULL"
      when TrueClass
        "1" #(column and column.type == :boolean ? "'t'" : "1")
      when FalseClass
        "0" #(column and column.type == :boolean ? "'f'" : "0")
      when Float, Fixnum, Integer, Numeric
        "'#{obj}'"
      when Date  #this right?
        "'#{obj}'"
      when Time, DateTime
        "'#{obj.strftime("%Y-%m-%d %H:%M:%S")}'"
      else
        "'#{obj.to_yaml}'"
      end
    end

    def sql_type( obj )
      case obj
      when String                then :text
      when Integer, Fixnum       then :integer
      when Float, Numeric        then :numeric
      when Date, DateTime        then :timestamp
      when TrueClass, FalseClass then :boolean
      when NilClass              then :NULL
      else :text # serialized
      end
    end

    #  from VALUE to COLUMN
    #
    #              |  :text    :numeric    :integer    :boolean    :timestamp
    # -------------+------------------------------------------------------------
    #   :text      |   nil      text        text        text        text
    #   :numeric   |  .to_s     nil         numeric     numeric*    REF
    #   :integer   |  .to_s    .to_f        nil         integer*    REF
    #   :boolean   |  .to_s*   .to_f*      .to_i*       nil         REF
    #   :timestamp |  .to_s                             REF         nil
    #   :array

    def generalize_column( table, column, value )
      column_type = # get from table( column )
      value_type =  sql_type( value )
      return if column_is_reference?( table, column )
      return if column_type == value_type
      if value_type == :numeric and column_type == :integer
        sql = "ALTER TABLE #{table} ALTER COLUMN #{column} TYPE numeric;"
        execute( sql )
      else
        # create reference columns
        ref_table = value.class.record_table
        sql = "ADD COLUMN #{column}_id integer REFERENCES #{ref_table} ( record_id );"
        execute( sql )
        # copy old columns to reference table and record ids
        sql = ""
        # remove old column
      end
    end

    #def generalize_value( table, column, value )
    #end

    def add_column( table, name, primer )
      case primer
      when String
        "ALTER TABLE #{table} ADD COLUMN #{name} text;"
      when Integer
        "ALTER TABLE #{table} ADD COLUMN #{name} integer;"
      when Float, Numeric
        "ALTER TABLE #{table} ADD COLUMN #{name} numeric;"
      when Date, DateTime
        "ALTER TABLE #{table} ADD COLUMN #{name} timestamp;"
      when TrueClass, FalseClass
        "ALTER TABLE #{table} ADD COLUMN #{name} boolean;"
      #when Array
      #  if ref_table = primer[0].class.record_table  # one-to-many
      #    "ALTER TABLE #{ref_table} ADD COLUMN #{name}_id integer REFERENCES #{table} ( record_id );"
      #  else
      #    ref_type = sql_type( primer[0] )
      #    "ALTER TABLE #{table} ADD COLUMN #{name} #{ref_type}[];"
      #  end
      else
        if primer.class.respond_to?( :table_class )
          table = primer.class.record_table  # one-to-one reference
          "ALTER TABLE #{table} ADD COLUMN #{name} integer REFERENCE #{table} ( record_id );"
        else
          "ALTER TABLE #{table} ADD COLUMN #{name} text;"  # serialized object
        end
      end
    end

    ################
    # Where Player #
    ################

    # NOT (!) is going to be a problem. Argh!

    class SqlWherePlayer

      def initialize( store )
        @store = store
      end

      def &(x)
        "(#{self}) AND #{@store.quote(x)}"
      end

      def |(x)
        "(#{self}) OR #{@store.quote(x)}"
      end

      def between(x, y)
        "(#{self}) BETWEEN #{@store.quote(x)} AND #{@store.quote(y)}"
      end

      def method_missing( field )
        field if columns.include? field
        super
      end

    end







# 
#     def prime(klass)
#       @tables[klass] = Table.new(klass, self)
#     end
# 
#     def cache(klass)
#       @tables[klass].cache
#     end
# 
#     ###############
#     # Table Class #
#     ###############
# 
#     class Table
# 
#       def initialize( klass, store )
#         @klass = klass
#         @store = store
#         @location = File.join( store.location, klass.name.pathize )
#         @records = {}
#       end
# 
#       def load( recid )
#         @records[ recid ]
#       end
# 
#       def save( data, recid=nil )
#         recid ||= @next_index
#         path = File.join( @location, "#{recid}.yml" )
#         output = data.to_h.to_yaml
#         File.open( path, "w+" ) { |f| f << output }
#         if recid == @next_index
#           @records[recid] = data
#           @next_index += 1
#         end
#         recid
#       end
# 
#       def delete( recid )
#         @records.delete(recid)
#         # remove file (move to trashbin)
#         path = File.join( @location, "#{recid}.yml" )
#         FileUtil.mv( path, File.join( @store.location, klass.name.pathize, '_trash', "#{recid}.yml" ) )
#         recid
#       end
# 
#       def select( &block )
#         # this is to enusre it follows specs
#         r = block.call( Recorder.new )
#         # actual selection
#         @records.values.select( &block )
#       end
# 
#       def index
#         @records.keys.sort
#       end
# 
#       # loads in all records (this store is 100% memory based)
# 
#       def cache
#         Dir.chdir( @location ) do
#           #prime unless File.file?('0.yml')
#           primer = YAML::load(File.new('0.yml'))
#           @recordkeys = primer.keys
#           @structclass = Struct.new(*@recordkeys)
#           recs = Dir.glob('*.yml')
#           recs.each do |f|
#             data = YAML::load(File.new(f))
#             @records[f.to_i] = struct(data)
#           end
#         end
#         @next_index = index.last.to_i + 1
#       end
# 
#       def recordkeys ; @recordkeys ; end
# 
#       def struct(data)
#         @structclass.new(*data.values_at(*recordkeys))
#       end
# 
#       #def prime
#       #  @klass.instance_variables
#       #end
# 
#     end

  end

  Stores.register(:psql, PsqlStore)

end


