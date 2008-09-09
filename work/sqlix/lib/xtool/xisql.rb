# XMLToolKit - XiSQL (SQLiX)
# Copyright (c) 2002 Thomas Sawyer, LGPL

require 'sqlix/dbconnection'

module XMLToolKit

  # class is used for interopolating regular relational tables with xml
  class XiSQL

    attr_reader :sqls   # the array of sql statements generated by XiSQL

    # Connects to the database using the DBConnection class.
    def initialize(dbconnection)
      @dbi = dbconnection
    end

    # Takes an xml document and returns an array of insert or update queries for every record in the document.
    def make_sql(xml_file_or_string)
      src = REXML::SourceFactory.create_from(xml_file_or_string)  # REXML allows to parse a file or a string
      listener = XiSQL_Listener.new(@dbi)                     # initialize listener passing the DBConnection object
      REXML::Document.parse_stream(src, listener)                 # parse it!
      listener.build_sql                                          # build the sql statements from the parse
      @sqls = listener.sqls                                       # here's are sql statements array
      return @sqls                                                # pass the sql array back for convienence
    end
    
    # Applies sqls against the database within a single transaction.
    def apply_sql
      @dbi.connection.transaction do
        @sqls.each do |sql|
          @dbi.connection.do(sql)
        end
      end
    end
    
    
    private  # ---------------------------------------
    
    # REXML stream parser engine
    class XiSQL_Listener
    
      attr_reader :sqls  # the array of sql statements generated by this listener
    
      #
      def initialize(dbi)
        @dbi = dbi                 # the DBConnection object we are using
        @root = ''                 # stores the root tag whihc is rather useless to us
        @value = ''                # temp variable to hold field value
        @field = ''                # temp variable to hold field name
        @set = 0                   # a set cooresponds to a single sql statement which it numbers
        @tagset_count = 0          # total count of sets (i.e. sql statements)
        @tagset = [ 0 ]            # this is a stack to track our current set
        @tagset_table = []         # stores the table each set applies to
        @tagset_conditions = []    # stores xml attributes for each set, which are used in the where condition for update queries
        @tagset_entry = {}         # stores [field, value] assoc. arrays to be used in sql statement
        @tags = []                 # this is a stack to track our current tag name
        @at_start = false          # have we just parsed a start tag?
        @at_end = false            # have we just parsed an end tag?
        @sqls = []                 # the array of sql statements generated by this listener
      end
    
    
      def method_missing(a, *b)
        raise "Method Missing: #{a}, #{b}"
      end
        
      def xmldecl(ver, enc, stand)
        # ignore xml declaration
      end
      
      def doctype(name, *contents)
        # ignore doctype
      end
      
      def instruction(name, instruction)
        # ignore any instructions (for now)
      end
      
      def comment(comment)
        # ignore comments
      end
      
        
      def tag_start(name, attributes)
        if @root == ''
          @root = name  # grab the root tag and get it out of the way, all subsequent parent tags must be table names
        else
          if @at_start
            @tagset.push(@tagset_count)                           # start the new set by pushing it onto stack
            @tagset_table[@tagset_count] = @tags.last             # assign the table for this set
            @tagset_conditions[@tagset_count] = @attributes_hold  # pickup held attributes
            @tagset_count += 1                                    # increment for next set
          end
          @tags.push(name)                        # push current tag name on to stack
          # hold attributes if any
          @attributes_hold = []                   # hold current attributes
          attributes.each do |a|
            @attributes_hold << [ a[0], a[1] ]
          end
          @at_start = true                        # yes we just parsed a start tag
          @at_end = false                         # and not an end tag
        end
      end
    
    
      def tag_end(name)
        if @at_end     # did we just parse an end tag and now we're doing another?
          @tagset.pop  # finish with this set by popping it off the stack
        else
          if not @tagset_entry[@set]               # do we have a entry for this set yet?
            @tagset_entry[@set] = []               # entries will be an arrays
          end
          @tagset_entry[@set] << [@field, @value]  # assign the entry with the [field, value] assoc. array
        end
        @tags.pop                                  # finished with this tag, pop it off the stack
        @at_start = false                          # did not just parse a start tag
        @at_end = true                             # just parsed an end tag
      end
    
      
      def text(value)
          @value = value          # hold the current contents of the current tag
          @field = @tags.last     # hold the current tag name
          @set = @tagset.last     # hold the current set
      end
    
    
      # Takes the listeners parse and creates the sql statements array.
      def build_sql
        @tagset_count.times do |index|
          table = prefixless(@tagset_table[index])
          if @tagset_conditions[index].length > 0
            # update
            sql = "UPDATE #{table} SET "
            @tagset_entry[index].each do |a|
              cn = prefixless(a[0])
              cv = @dbi.sql_typify(table, cn, a[1])
              sql = sql + "#{cn}=#{cv},"
            end
            sql.chomp!(',')
            sql = sql + " WHERE "
            @tagset_conditions[index].each do |c|
              cn = prefixless(c[0])
              cv = @dbi.sql_typify(table, cn, c[1])
              sql = sql + "#{cn}=#{cv},"
            end
            sql = sql.chomp(',') + ';'
          else
            # insert
            sql = "INSERT INTO #{table} ("
            @tagset_entry[index].each do |a|
              cn = prefixless(a[0])
              sql = sql + "#{cn},"
            end
            sql = sql.chomp(',') + ') VALUES ('
            @tagset_entry[index].each do |a|
              cn = prefixless(a[0])
              cv = @dbi.sql_typify(table, cn, a[1])
              sql = sql + "#{cv},"
            end
            sql = sql.chomp(',') + ');'
          end
          @sqls << sql
        end
      end

      # Removes the namespace prefix from a tag name.
      def prefixless(tagname)
        if tagname =~ /[:]/
          return tagname.strip.split(':')[1]
        else
          return tagname.strip
        end
      end

    end  # XMLtR_Listener

  end  #

end  # XMLToolKit
