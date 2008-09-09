
=begin

Recordable - Object Relational Mapping
Copyright (c)2004 Thomas Sawyer, LGPL

= Introduction

Recordable is a mixin to allow objects
to be easily stored and retrieved from a database.

= Installation

To install simply unpack the gzipped tarball into your local site_ruby path.
This path is usually +/usr/local/lib/site_ruby/1.8/+.
An install script is not currently provided.

= Current Limitations

Presently resricted to using the ActiveDBA library.
DBI may be supported in the future.

== Requirements

Ruby 1.8+
Active DBA 1.0+

== Usage

Your object will require a new method called <i>table</i>
which returns the name of the table that stores the object type.
it will also need methods <i>record</i> and <i>record=</i> to 
store the current "id" of a record.

After this, simply mixin a class with include Recordable.
Doing so will give your object some new methods such as
insert_into_database and load_from_database.

The key to Recordable's automatic ability is the use of the
database attribute (field) names as method calls to the mixed object.
Thus your object needs <i>attribute<i> and <i>attribute=</i> accessor
methods defined for the fields you wish to be mapped to the table.
Recordable will ignore unused fields, so you don't necessarily need to cover
every database attribute and vice-versa.

Please refer to the rdocs, to understand this better.

= Authentication

Package:: Recordable
Author:: Thomas Sawyer
License:: Copyright (c) 2004 Thomas Sawyer, LGPL

= Copy License

Recordable is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

Recordable is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with Recordable; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

=end

require 'databob'

# Some minor internal additions to Ruby's built-in classes

module Kernel

  #def respond_with_value(sym)
  #  return nack if not respond_to?(sym)
  #  v = send(sym)
  #  #case v
  #  #when nil, false, 0, 0.0, '', [], {}
  #  #  return false
  #  #else
  #  return v
  #  #end
  #end

  def set_all(ahash)
    ahash.to_h.each { |name, value|
      self.send("#{name}=", value) if self.respond_to?("#{name}=".intern)
    }
  end
end

class Hash
  def to_h; rehash; end
end


# Recordable
#   Mixin module to automatically map an object to a relational database
module Recordable

  # Modules

  # RecordReader
  #   Reader methods for ORM
  #
  # Optional singleton methods:
  # * sql_where()
  # * load_exclude()
  #
  # Provides:
  # * load_from_database()
  # * load_related_from_database()
  #
  module RecordReader

    def record_load
      r = self.class.connection.select_one(sql_select)
      if r
        ### need to clean up the results, for example dates are DBI dates
        self.set_all(r.to_h)
        success = true
      else
        success = false
      end
      success
    end

    def record_load_related
      # if depth > 0 ?
      # find all instance valiables that match my_* and my_*_collection
      ho = instace_variables.collect { |iv| iv =~ /^my_.+$/ }
      hc = instace_variables.collect { |iv| iv =~ /^my_.+_collection$/ }
      ho.each { |hor| hor.load_from_database if hor.respond_to?(:load_from_database) }
      hc.each { |hcr|
        hcr.each { |hcri|
          hcri.load_from_database if hcri.respond_to?(:load_from_database)
        }
      }
    end

    protected  #---------------------------------------------------

    def sql_select
      tbl = self.class.table
      keyf = self.class.primary_key
      keyv = send(keyf.intern).to_i
      le = respond_to?(:load_exclude) ? (load_exclude || []) : []
      if le.empty?
        sql = "SELECT * FROM #{tbl}"
        if respond_to?(:sql_where)
          sql << " WHERE #{sql_where}"
        else
          sql << " WHERE #{keyf}=#{keyv}"
        end
      else
        self.class.connection.meta.fields[tbl].each { |name|
          if respond_to?(name) and not le.include?(name)
            new_value = send(name)
            fields << name
          end
          fields << keyf if not fields.include?(keyf)
        }
        if not fields.empty?
          sql = "SELECT " << fields.join(',') << " FROM #{tbl}"
          if respond_to?(:sql_where)
            sql << " WHERE #{sql_where}"
          else
            sql << " WHERE #{keyf}=#{keyv}"
          end
        else
          raise "no attribute of the object cooresponds to the load query. that's useless!"
        end
      end
      return sql
    end

  end  # RecordReader


  # RecordWriter
  #   Writer methods for ORM
  #
  # Optional singleton methods:
  # * update_exclude()
  # * insert_exclude()
  #
  # Provides:
  # * update_database()
  # * insert_into_database()
  # * delete_from_database()
  #
  # * mark()
  # * mark()=
  #
  module RecordWriter

    #attr_accessor :mark => :to_b

    def record_save
      # if record exits then update else insert
      r = dbh.select_one(sql_select)
      if not r
        record_insert
      else
        record_update
      end
    end

    def record_update  #(depth=1)
      success = nil
      sql = nil
      dbh = self.class.connection
      tbl = self.class.table
      keyf = self.class.primary_key
      keyv = send(keyf.intern).to_i
      # make sure we have a record to update
      r = dbh.select_one(sql_select)
      raise "cannot update, record not found" if not r
      # collect fields with values that have changed
      ue = respond_to?(:update_exclude) ? update_exclude : []
      fields = []
      r.each { |name, value|
        if respond_to?(name.intern) and name.to_s != keyf and not ue.include?(name)
          new_value = self.send(name.intern)
          fields << [name, new_value] if new_value != value
        end
      }
      # build update sql
      if not fields.empty?
        sql = "UPDATE #{tbl} SET " 
        #sql << fields.collect{ |p| "#{p[0]}=#{dbh.sql_format(tbl, p[0], p[1])}" }.join(',')
        sql << fields.collect{ |p| "#{p[0]}=#{dbh.quote(p[1])}" }.join(',')
        sql << " WHERE #{keyf}=#{keyv}"
      end
      # update
      if sql
        dbh.begin_db_transaction
        begin
          dbh.update(sql)
          # related recordsets ?
          #if depth > 0
          #  self.related_recordsets.each { |rrs| rrs.update_database(depth - 1) }
          #end
        rescue
          dbh.rollback_db_transaction
          success = false
          raise  # ?
        else
          dbh.commit_db_transaction
          success = true
        end
      end
      success
    end

    #
    def record_insert  #(depth=1)
      new_key = nil
      sql = nil
      dbh = self.class.connection
      tbl = self.class.table
      keyf = self.class.primary_key
      keyv = send(keyf.intern).to_i
      fields = []
      dbh.meta.fields[tbl].each { |name|
        if respond_to?(name.intern) and name.to_s != keyf and not insert_exclude.include?(name)
          new_value = send(name.intern)
          fields << [name, new_value]
        end
      }
      if not fields.empty?
        sql = "INSERT INTO #{tbl} (" 
        sql << fields.collect{ |p| p[0] }.join(',') 
        sql << ') VALUES (' 
        #sql << fields.collect{ |p| dbh.sql_format(tbl, p[0], p[1]) }.join(',')
        sql << fields.collect{ |p| dbh.quote(p[1]) }.join(',') 
        sql << ')'
      end
      if sql
        dbh.begin_db_transaction
        begin
          new_key = dbh.insert(sql)

          ### CURRENTLY THIS ONLY WORKS WITH PG DBD!!!!!!!!
          ### REMOVE THANKS TO ACTIVE RECORD DB ADAPTERS
          #sql = "SELECT currval('#{tbl}_#{keyf}_seq') as new_key"
          #new_key = dbh.select_one(sql)['new_key']
          #self.send("#{keyf}=".intern, new_key)

          #if depth > 0 ?
          #  # related recordsets
          #  related_recordsets.each { |rrs| rrs.update_database(depth - 1) }
          #end
        rescue
          self.dbh.rollback_db_transaction
          success = false
        else
          self.dbh.commit_db_transaction
          success = true
        end
      end
      return new_key
    end

    #
    def record_delete
      success = nil
      dbh = self.class.connection
      tbl = self.class.table
      keyf = self.class.primary_key
      keyv = send(keyf.intern).to_i
      sql = "DELETE FROM #{tbl} WHERE #{keyf}=#{keyv}"
      dbh.begin_db_transaction
      begin
        dbh.delete(sql)
        # related records?
      rescue
        dbh.rollback_db_transaction
        success = false
        #raise  # ?
      else
        dbh.commit_db_transaction
        success = true
      end
      success
    end

  end  # RecordWriter


  # Realtionships
  #   Methods for linking one class to another in relational fashion
  module Relationships

    #
    def has_one(klass)
      kname = klass.name.downcase
      self.class_eval <<-EOS
        def #{kname}
          @#{kname}
        end
        def #{kname}=(k)
          @#{kname} = k
        end
      EOS
    end

    #
    def has_many(klass)
      kname = klass.name.downcase
      self.class_eval <<-EOS
        def #{kname}_collection
          @#{kname}_collection || []
        end
      EOS
    end

  end  # Relationships


  # ClassBuilder
  #   Provides methods to automatically build-out a class based on database table information.
  module Builder

    def build_class(*overwrite)
      # pluralization issue
      tbl = respond_to?(:table) ? self.table : self.name.downcase

      connection.columns(tbl).each { |c|
        # c has name, default and type
        if self.public_instance_methods(true).include?(c.name) and (! overwrite.include?(c.name))
          warn "Will not create reader for method ##{c.name}. " +
               "It already exists and was not specified in the overwrite list." #if $DEBUG
        else
          class_eval <<-EOS
            def #{c.name}
              @#{c.name}
            end
          EOS
        end
        if self.public_instance_methods(true).include?("#{c.name}=") and (! overwrite.include?(c.name))
          warn "Will not create writer for method ##{c.name}. " +
               "It already exists and was not specified in the overwrite list." #if $DEBUG
        else
          class_eval <<-EOS
            def #{c.name}=(v)
              @#{c.name} = v
            end
          EOS
        end
      }
    end

    # create datatable from a class definition
    def build_table
      fields = {}
      vars = instance_variables.collect{ |iv| iv.gsub(/^@/,'') }
      writers = instance_methods.select{ |m| /=$/ =~ m }.collect{ |m| m.gsub(/=$/,'') }
      fieldnames = ( writers | vars )
      fieldnames.each { |m|
        fields[m] = {}
        [ :type, :default, :unique, :sql ].each { |prop|
          fields[m][prop] = ann(m)[prop]
        }
      }
      connection.
    end

  end


  #
  #
  module Utilities

    #include ClassInheritableAttributes

    # Returns objects for the records responding to either a specific id (1), a list
    # of ids (1, 5, 6) or an array of ids. If only one ID is specified, that object 
    # is returned directly. If more than one ID is specified, an array is returned.
    # Examples:
    #   Person.find(1)       # returns the object for ID = 1
    #   Person.find(1, 2, 6) # returns an array for objects with IDs in (1, 2, 6)
    #   Person.find([7, 17]) # returns an array for objects with IDs in (7, 17)
    # +RecordNotFound+ is raised if no record can be found.
    def find(*ids)
      ids = [ ids ].flatten.compact
      if ids.length > 1
        ids_list = ids.map{ |id| "'#{id}'" }.join(", ")
        objects  = find_all("#{primary_key} IN (#{ids_list})", primary_key)
        if objects.length == ids.length
          return objects
        else
          raise RecordNotFound, "Couldn't find #{name} with ID in (#{ids_list})"
        end
      elsif ids.length == 1
        id = ids.first
        sql = "SELECT * FROM #{table_name} WHERE #{primary_key} = '#{id}'"
        sql << "AND type = '#{name.gsub(/.*::/, '')}'" unless descents_from_active_record?
        if record = connection.select_one(sql, "#{name} Find")
          instantiate(record)
        else
          raise RecordNotFound, "Couldn't find #{name} with ID = #{id}"
        end
      else
        raise RecordNotFound, "Couldn't find #{name} without an ID"
      end
    end

    # Works like find, but the record matching +id+ must also meet the +conditions+.
    # +RecordNotFound+ is raised if no record can be found matching the +id+ or meeting the condition.
    # Example:
    #   Person.find_on_conditions 5, "first_name LIKE '%dav%' AND last_name = 'heinemeier'"
    def find_on_conditions(id, conditions)
      find_first("#{primary_key} = '#{id}' AND #{sanitize_conditions(conditions)}") || 
        raise(RecordNotFound, "Couldn't find #{name} with #{primary_key} = #{id} on the condition of #{conditions}")
    end

    # Returns an array of all the objects that could be instantiated from the associated
    # table in the database. The +conditions+ can be used to narrow the selection of objects (WHERE-part),
    # such as by "color = 'red'", and arrangement of the selection can be done through +orderings+ (ORDER BY-part),
    # such as by "last_name, first_name DESC". A maximum of returned objects can be specified in +limit+. Example:
    #   Project.find_all "category = 'accounts'", "last_accessed DESC", 15
    def find_all(conditions = nil, orderings = nil, limit = nil, joins = nil)
      sql  = "SELECT * FROM #{table_name} " 
      sql << "#{joins} " if joins
      add_conditions!(sql, conditions)
      sql << "ORDER BY #{orderings} " unless orderings.nil?
      sql << "LIMIT #{limit} " unless limit.nil?
      find_by_sql(sql)
    end

    # Works like find_all, but requires a complete SQL string. Example:
    #   Post.find_by_sql "SELECT p.*, c.author FROM posts p, comments c WHERE p.id = c.post_id"
    def find_by_sql(sql)
      connection.select_all(sql, "#{name} Load").inject([]) { |objects, record| objects << instantiate(record) }
    end

    # Returns the object for the first record responding to the conditions in +conditions+,
    # such as "group = 'master'". If more than one record is returned from the query, it's the first that'll
    # be used to create the object. In such cases, it might be beneficial to also specify
    # +orderings+, like "income DESC, name", to control exactly which record is to be used. Example:
    #   Employee.find_first "income > 50000", "income DESC, name"
    def find_first(conditions = nil, orderings = nil)
      sql  = "SELECT * FROM #{table_name} "
      add_conditions!(sql, conditions)
      sql << "ORDER BY #{orderings} " unless orderings.nil?
      sql << "LIMIT 1"
      record = connection.select_one(sql, "#{name} Load First")
      instantiate(record) unless record.nil?
    end

    # Creates an object, instantly saves it as a record (if the validation permits it),
    # and returns it. If the save fail under validations, the unsaved object is still returned.
    def create(attributes = nil)
      object = new(attributes)
      object.save
      object
    end

    # Finds the record from the passed +id+, instantly saves it with the passed +attributes+
    # (if the validation permits it), and returns it. If the save fail under validations,
    # the unsaved object is still returned.
    def update(id, attributes)
      object = find(id)
      object.attributes = attributes
      object.save
      object
    end

    # Updates all records with the SET-part of an SQL update statement in +updates+.
    # A subset of the records can be selected by specifying +conditions+. Example:
    #   Billing.update_all "category = 'authorized', approved = 1", "author = 'David'"
    def update_all(updates, conditions = nil)
      sql  = "UPDATE #{table_name} SET #{updates} "
      add_conditions!(sql, conditions)
      connection.update(sql, "#{name} Update")
    end

    # Destroys the objects for all the records that matches the +condition+ by instantiating
    # each object and calling the destroy method. Example:
    #   Person.destroy_all "last_login < '2004-04-04'"
    def destroy_all(conditions = nil)
      find_all(conditions).each { |object| object.destroy }
    end

    # Deletes all the records that matches the +condition+ without instantiating the
    # objects first (and hence not calling the destroy method). Example:
    #   Post.destroy_all "person_id = 5 AND (category = 'Something' OR category = 'Else')"
    def delete_all(conditions = nil)
      sql = "DELETE FROM #{table_name} "
      add_conditions!(sql, conditions)
      connection.delete(sql, "#{name} Delete all")
    end

    # Returns the number of records that meets the +conditions+. Zero is returned if no records match. Example:
    #   Product.count "sales > 1"
    def count(conditions = nil)
      sql  = "SELECT COUNT(*) FROM #{table_name} "
      add_conditions!(sql, conditions)
      count_by_sql(sql)
    end

    # Returns the result of an SQL statement that should only include a COUNT(*) in the SELECT part.
    #   Product.count "SELECT COUNT(*) FROM sales s, customers c WHERE s.customer_id = c.id"
    def count_by_sql(sql)
      count = connection.select_one(sql, "#{name} Count").values.first
      return count ? count.to_i : 0
    end

    # Increments the specified counter by one. So 
    #   <tt>DiscussionBoard.increment_counter("post_count", discussion_board_id)</tt>
    # would increment the "post_count" counter on the board
    # responding to discussion_board_id. This is used for caching aggregate values, so that
    # they doesn't need to be computed every time. Especially important for looping over a 
    # collection where each element require a number of aggregate values. Like the DiscussionBoard
    # that needs to list both the number of posts and comments.
    def increment_counter(counter_name, id)
      object = find(id)
      object.update_attribute(counter_name, object.send(counter_name) + 1)
    end

    # Works like increment_counter, but decrements instead.
    def decrement_counter(counter_name, id)
      object = find(id)
      object.update_attribute(counter_name, object.send(counter_name) - 1)
    end

    # Attributes named in this macro are protected from mass-assignment, such as
    # <tt>new(attributes)</tt> and <tt>attributes=(attributes)</tt>. Their assignment
    # will simply be ignored. Instead, you can use the direct writer methods to do
    # assignment. This is meant to protect sensitive attributes to be overwritten
    # by URL/form hackers. Example:
    #
    #   class Customer < ActiveRecord::Base
    #     attr_protected :credit_rating
    #   end
    #
    #   customer = Customer.new("name" => David, "credit_rating" => "Excellent")
    #   customer.credit_rating # => nil
    #   customer.attributes = { "description" => "Jolly fellow", "credit_rating" => "Superb" }
    #   customer.credit_rating # => nil
    #
    #   customer.credit_rating = "Average"
    #   customer.credit_rating # => "Average"
#    def attr_protected(*attributes)
#      write_inheritable_array("attr_protected", attributes)
#    end

    # Returns an array of all the attributes that have been protected from mass-assigment.
#    def protected_attributes # :nodoc:
#      read_inheritable_attribute("attr_protected")
#    end

    # If this macro is used, only those attributed named in it will be accessible for
    # mass-assignment, such as <tt>new(attributes)</tt> and <tt>attributes=(attributes)</tt>.
    # This is the more conservative choice for mass-assignment protection. If you'd rather
    # start from an all-open default and restrict attributes as needed, have a look at
    # attr_protected.
#    def attr_accessible(*attributes)
#      write_inheritable_array("attr_accessible", attributes)
#    end

    # Returns an array of all the attributes that have been made accessible to mass-assigment.
#    def accessible_attributes # :nodoc:
#      read_inheritable_attribute("attr_accessible")
#    end

    # Guesses the table name (in forced lower-case) based on the name of the class
    # in the inheritance hierarchy descending directly from ActiveRecord. So if the
    # hierarchy looks like: Reply < Message < ActiveRecord, then Message is used to
    # guess the table name from even when called on Reply. The guessing rules are as follows:
    # * Class name doesn't end in "s" or "y": An "s" is appended, so a Comment class becomes a comments table. 
    # * Class name ends in a "y": The "y" is replaced with "ies", so a Category class becomes a categories table. 
    # * Class name ends in an "s": No additional characters are added or removed.
    # * Class name with word compositions: Compositions are underscored, so CreditCard class becomes credit_cards table.
    # Additionally, the class-level table_name_prefix
    # is prepended to the table_name and the table_name_suffix is appended. So if you have
    # "myapp_" as a prefix, the table name guess for an Account class becomes "myapp_accounts".
    #
    # You can also overwrite this class method to allow for unguessable links, such as a Person class with a link to a
    # People table. Example:
    #
    #   class Person < ActiveRecord::Base
    #      def self.table_name() "people" end
    #   end
    def table_name(class_name = class_name_of_active_record_descendant(self))
      table_name_prefix + undecorated_table_name(class_name) + table_name_suffix
    end

    # Defines the primary key field -- can be overridden in subclasses. Overwritting will negate any effect of the
    # primary_key_prefix_type setting, though.
    def primary_key
      case primary_key_prefix_type
        when :table_name                 
          "#{class_name_of_active_record_descendant(self).downcase}id"
        when :table_name_with_underscore
          "#{class_name_of_active_record_descendant(self).downcase}_id"
        else
          "id"
      end
    end

    # Turns the +table_name+ back into a class name following the reverse rules of +table_name+.
    def class_name(table_name) # :nodoc:
      # remove any prefix and/or suffix from the table name
      class_name = table_name[table_name_prefix.length..-(table_name_suffix.length + 1)]

      class_name = class_name.capitalize.gsub(/_(.)/) { |s| $1.capitalize }

      if pluralize_table_names
        if class_name[-3,3] == "ies"
          class_name = class_name[0..-4] + "y"
        elsif class_name[-1,1] == "s"
          class_name = class_name[0..-2]
        end
      end

      class_name
    end

    # Returns an array of column objects for the table associated with this class.
    def columns
      @columns ||= connection.columns(table_name, "#{name} Columns")
    end

    # Returns an array of column objects for the table associated with this class.
    def columns_hash
      @columns_hash ||= columns.inject({}) { |hash, column| hash[column.name] = column; hash }
    end

    # Returns an array of columns objects where the primary id, all columns ending in "_id" or "_count", 
    # and columns named "type" has been removed.
    def content_columns
      columns.reject { |c| c.name == primary_key || c.name =~ /(_id|_count)$/ || c.name == "type" }
    end

    # Transforms attribute key names into a more humane format, such as "First name" instead of "first_name". Example:
    #   Person.human_attribute_name("first_name") # => "First name"
    def human_attribute_name(attribute_key_name)
      attribute_key_name.gsub(/_/, " ").capitalize unless attribute_key_name.nil?
    end

    def descents_from_active_record? # :nodoc:
      superclass == Base
    end

    # Used to sanitize objects before they're used in an SELECT SQL-statement.
    def sanitize(object) # :nodoc:
      return object if Fixnum === object
      object.to_s.gsub(/([;:])/, "").gsub('##', '\#\#').gsub(/'/, "''") # ' (for ruby-mode)
    end

    private
      # Finder methods must instantiate through this method to work with the single-table inheritance model
      # that makes it possible to create objects of different types from the same table.
      def instantiate(record)
        object = record_with_type?(record) ? compute_type(record["type"]).allocate : allocate
        object.instance_variable_set("@attributes", record)
        return object
      end

      # Returns true if the +record+ has a type column and is using it.
      def record_with_type?(record)
        record.include?("type") && !record["type"].nil? && !record["type"].empty?
      end

      # Returns the name of the type of the record using the current module as
      # a prefix. So descendents of MyApp::Business::Account would be appear as
      # "MyApp::Business::AccountSubclass".
      def type_name_with_module(type_name)
        self.name =~ /::/ ? self.name.scan(/(.*)::/).first.first + "::" + type_name : type_name
      end

      # Adds a sanitized version of +conditions+ to the +sql+ string. Note that it's the
      # passed +sql+ string is changed.
      def add_conditions!(sql, conditions)
        sql << "WHERE #{sanitize_conditions(conditions)} " unless conditions.nil?
        sql << (conditions.nil? ? "WHERE " : " AND ") + "type = '#{name.gsub(/.*::/, '')}' " unless descents_from_active_record?
      end

      # Guesses the table name, but does not decorate it with prefix and suffix information.
      def undecorated_table_name(class_name = class_name_of_active_record_descendant(self))
        table_name = class_name.gsub(/.*::/, '').gsub(/([a-z])([A-Z])/, '\1_\2').downcase

        if pluralize_table_names
          case table_name[-1,1]
            when "s" # no change
            when "y" then table_name = table_name[0..-2] + "ies"
            else table_name = table_name + "s"
          end
        end

        return table_name
      end

    protected

      # Returns the class type of the record using the current module as a prefix. So descendents of
      # MyApp::Business::Account would be appear as MyApp::Business::AccountSubclass.
      def compute_type(type_name)
        type_name_with_module(type_name).split("::").inject(Object) do |final_type, part| 
          final_type = final_type.const_get(part)
        end
      end

      # Returns the name of the class descending directly from ActiveRecord in the inheritance hierarchy.
      def class_name_of_active_record_descendant(klass)
        if klass.superclass == Base
          return klass.name
        elsif klass.superclass.nil?
          raise ActiveRecordError, "#{name} doesn't belong in a hierarchy descending from ActiveRecord"
        else
          class_name_of_active_record_descendant(klass.superclass)
        end
      end

      # Accepts either a condition array or string. The string is returned untouched, but the array has each of
      # the condition values sanitized.
      def sanitize_conditions(conditions)
        if Array === conditions
          statement, values = conditions[0], conditions[1..-1]
          values.collect! { |value| sanitize(value) }
          conditions = statement % values
        end
        return conditions
      end

  end  # Utilities


  # Main

  include RecordReader
  include RecordWriter

  # This will be automatically inherited in the class scope
  # of any class that includes the Recordable module
  module ClassMixin
    attr_accessor :table, :primary_key
    include ::DataBob::DatabaseConnection
    include Recordable::Utilities
    include Recordable::Relationships
    include Recordable::ClassBuilder
  end

  def self.append_features(klass)
    klass.extend self::ClassMixin
    super
  end

end  # Recordable
