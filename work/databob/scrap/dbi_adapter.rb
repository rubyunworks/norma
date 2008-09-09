# NOT YET FUNCTIONAL !!!

=begin
  Jigsaw - DBI Adapter
  Copyright (c)2002 Thomas Sawyer, LGPL

= Description

  This module directly alters the standard DBI module.

= License

  Jigsaw is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  Jigsaw is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with Jigsaw; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

=end


require 'dbi/dbi'

##
# This adds a method for any object and works on any object which
# has a to_i method. It does the same as to_i except a value of 0
# is converted to a nil. Useful for record keys!
#

class Object

  def to_r
    self.to_i == 0 ? nil : self.to_i
  end

end


module DBIze

  # DBI CONNECTION
  module DatabaseConnection
    
    def connection
      return DBI.instance(*@connection)
    end
    
    def connection_set(dsn, username, password='', optional_parameters_hash={})
      @connection = [dsn, username, password, optional_parameters_hash]
    end
  
  end

end

    
module DBI

  # singleton instance
  # provides simple pooling of database connections
  # note: the pools are defined by dsn and username;
  # thus optional parameters are expected to be the same for these

  def DBI.instance(dsn, user, pass, *args)
    @@dbi = {} unless defined?(@@dbi)
    @@dbi["#{dsn}::#{user}"] ||= DBI.connect(dsn, user, pass, *args)
    return @@dbi["#{dsn}::#{user}"]
  end

  #
  # Meta
  #   Class for storing info about a database
  #   Easier than using straight DBI meta fucntionality
  #

  class Meta

    attr_reader :tables, :fields, :types

    def initialize(conn)

      @tables = {}
      @fields = {}
      @types = {}

      @tables = conn.tables  # coud use conn.tables.select { |table| table !~ /^pg_/ } remove all postgresql system tables

      @tables.each do |t|
        @fields[t] = []
        @types[t] = {}
        conn.columns(t).each do |c|
          @fields[t] << c['name'].intern                             # make an array of column names
          @types[t].update({ c['name'].intern => c['type_name'] })   # make a hash of column names => column types
        end
      end

    end

  end  # Meta

  #
  # DatabaseHandle
  #   Adds a few extra methods
  #

  class DatabaseHandle

    def meta
      @meta ||= Meta.new(self)
      return @meta
    end

    # returns a column value formatted for sql statments
    # (according to the database meta information)
    # essentially it deals with quoting strings.

    def sql_format(table, field_name, field_value)
      @meta ||= Meta.new(self)
      raise "invalid table: #{table}" if not @meta.types.has_key?(table)
      raise "invalid field name: #{field_name}" if not @meta.types[table].has_key?(field_name.intern)
      case @meta.types[table][field_name.intern].downcase
      when /point/
      raise "point fields not yet supported"
      when /interval/
        raise "interval fields not yet supported"
      when /int/, /serial/
        typified_value = field_value == nil ? 'NULL' : field_value
      when /float/, /double/, /money/, /numeric/, /decimal/
        typified_value = field_value
      when /bool/
        typified_value = field_value
      when /timestamp/, /date/
        if field_value.to_s.strip.empty?
          typified_value = 'NULL'          ####### MAY ONLY WORK WITRH POSTGRESQL ########
        else
          typified_value = %Q{'#{sql_escape(field_value.to_s.strip)}'}
        end
      when /var/, /char/, /text/
        typified_value = %Q{'#{sql_escape(field_value.to_s.strip)}'}
      else
        raise "unknown field type"
      end
      return typified_value
    end

    #
    # sql_escape escapes apostrophes in character string types
    #

    def sql_escape(str)
      return str.gsub(/[']/,"''")  # doubles up any apostrophes
    end

    #
    # typecast's a value according to database meta information
    #

    def typecast(table, field_name, field_value, honor_func=false)
      @meta ||= Meta.new(self)
      if @meta.types.has_key?(table)
        if @meta.types[table].has_key?(field_name.intern)
          case @meta.types[table][field_name.intern].downcase
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

  end  # DatabaseHandle

end  # DBI
