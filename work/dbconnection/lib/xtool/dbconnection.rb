# XMLToolKit - DBConnection
# Copyright (c)2002 Thomas Sawyer, LGPL

require 'tomslib/rubylib'  # should get rid of this dependency
require 'dbi/dbi'

module XMLToolKit

	# common class for accessing the database
	class DBConnection

		attr_reader :connection, :tables, :meta, :meta_names, :meta_types

		# initialize opens the connection to the database, prepares variables and calls meta (currently AutoCommit is set to false)
		def initialize(dsn, user, pass)
			@connection = DBI.connect(dsn, user, pass, 'AutoCommit' => false)
			@tables = []
			@meta = {}
			@meta_names = {}
			@meta_types = {}
			load_meta  # load database meta-information
		end

		# close method closes the database connection
		def close
			@connection.disconnect
		end

		# meta method collects meta information for the database
		def load_meta
			@tables = @connection.tables  # .select { |table| table !~ /^pg_/ }  # this only works with postgresql to remove system tables
			@tables.each do |table|
				@meta[table] = @connection.columns(table)
				@meta_names[table] = []
				@meta_types[table] = {}
				@meta[table].each do |column|
					@meta_names[table] << column['name']                                  # make an array of column names
				  @meta_types[table].update({ column['name'] => column['type_name'] })  # make a hash of column names => column types
				end
			end
		end

		# Returns a field value formatted for sql statments according to the database meta information
    # Essentially it deals with quoting strings
		def sql_format(table, field_name, field_value)
			if not @meta_types.has_key?(table)
				raise "invalid table: #{table}"
			end
			if not @meta_types[table].has_key?(field_name)
				raise "invalid field name: #{field_name}"
			end
			case @meta_types[table][field_name].downcase
			when /int/, /serial/
				if type != 'interval' and type != 'point'
					typified_value = field_value
				end
			when /float/, /double/, /money/, /numeric/, /decimal/
				typified_value = field_value
			when /bool/
				typified_value = field_value
			when /timestamp/, /date/
        if field_value.to_s.strip.empty?
          typified_value = 'NULL'
        else
          typified_value = sql_escape(field_value.to_s.strip).quote(true)
        end
			when /var/, /char/, /text/
				typified_value = sql_escape(field_value.to_s.strip).quote(true)
			end
			return typified_value
		end
	
		# sql_escape escapes apostrophes in character string types
		def sql_escape(str)
			return str.gsub(/[']/,"''")  # doubles apostrophes
		end
	
    # typecast's a value according to database meta information
    def typecast(table, field_name, field_value, honor_func=false)
      if @meta_types.has_key?(table)
				if @meta_types[table].has_key?(field_name)
          case @meta_types[table][field_name].downcase
          when /int/, /serial/
            if type != 'interval' and type != 'point'  # these type are not supported
              if honor_func and field_value.to_s.strip =~ /^\w+\(/
                typecast_value = field_value
              else
                typecast_value = field_value.to_i
              end
            else
              typecast_value = field_value.to_s.strip
            end
          when /float/, /double/, /money/, /numeric/, /decimal/
            if honor_func and field_value.to_s.strip =~ /^\w+\(/
              typecast_value = field_value
            else
              typecast_value = field_value.to_f
            end
          when /bool/
            if honor_func and field_value.to_s.strip =~ /^\w+\(/
              typecast_value = field_value
            else
              typecast_value = field_value.to_b
            end
          when /timestamp/, /date/
            typecast_value = field_value.to_s.strip
          when /var/, /char/, /text/
            typecast_value = field_value.to_s.strip
          else
            typecast_value = field_value.to_s.strip
          end
        else
          # pass through any field not found?
          typecast_value = field_value  #raise "table column, #{field_name}, does not exist"
        end
      else
        # pass through if table not found?
        typecast_value = field_value  #raise "typecast table, #{table}, does not exist"
      end
      return typecast_value
    end
    
	end  # DBConnection
	
end
