# XMLToolKit - SQLiX
# Copyright (c) 2002 Thomas Sawyer, LGPL

require 'jigsaw/dbconnection'
require 'tomslib/rerexml'
require 'tomslib/communication'

include TomsLib::Communication

module XMLToolKit

  class SQLiX
    
    # Connects to the database using the DBConnection class
    def initialize(*connection)
      if connection[0].is_a(Jigsaw::DBConnection)
        @dbi = connection[0]
      else
        dsn = connection[0]
        user = connection[1]
        pass = connection[2]
        @dbi = DBConnection.new(dsn, user, pass)  # connect to the database
      end
    end

    # Transforms a SQLiX embedded XML Document.
    # Takes a valid XML document as either a string or url, including local filename, or REXML::Document.
    # Use the seeds hash to feed the references of the initial row element.
    # Returns the resulting XML Document as a string, or as an REXML::Document if that was given.
    #
    # sqlix:query elements are in this format:
    #
    # <sqlix:query>
    #   <rowname_p query="select..." references="">
    #     <rowname_1 query="select..." references="">
    #       <rowname_1a query="select..." references="" />
    #       <rowname_1b query="select..." references="" />
    #     </rowname_1>
    #     <rowname_2 query="select..." references="" />
    #   </rowname_p>
    # </sqlix:query>
    #
    def transform(xml_source, seeds={})
      if xml_source.is_a?(REXML::Document)
        xml_document = xml_source
      else
        src = fetch_xml(xml_source)
        xml_document = REXML::Document.new(src)
      end
      queries = REXML::XPath.match(xml_document.root,'//x:query', {'x' => 'http://www.transami.net/namespace/sqlix'})
      queries.each do |element|
        listener = SQLiX_Listener.new(@dbi, seeds)
        el_str = ''
        element.write(el_str)
        REXML::Document.parse_stream(el_str, listener)
        new_element = listener.build_document
        new_element.elements.each do |el|
          element.parent.add_element(el)
        end
        element.remove
      end
      # return output
      if xml_source.is_a?(REXML::Document)
        return xml_document
      else
        xml_string = ""
        xml_document.write(xml_string)
        xml.gsub!(/>\s+</,'><')  # clean poor rexml whitespace handling
        return xml_string
      end
    end
    
    
    private  # --------------------------------------------------------------------
    
    # Query Class
    class Query
    
      attr_reader :name, :query, :references, :attributes
    
      def initialize(name, query, references, attributes)
        @name = name
        @query = query
        @references = references
        @attributes = attributes
      end

    end


    # Row Class
    class Row
      
      attr_reader :name, :row, :attributes, :children
      
      def initialize(name, row, attributes)
        @name = name
        @row = row
        @attributes = attributes
        @children = []
      end
      
      def <<(child)
        @children << child
      end
      
      # q! method, she's an odd one, takes a query and returns an array of Row objects produced
      # but also inserts those Row objects into this Row's (self) children
      # it is also neccessary to pass the DBConnection object the query will be run against
      #   this actually pisses me off in that the whole point of having this class
      #   nested in the XQuery class is to keep it private to it and access its instances (i.e. @dbi)
      #   but as far as i can tell the instance of XQuery this class partakes in, well isn't as such
      #   this leads me to believe that nesting a class is functionally meaningless and only useful for code structure
      def q!(query, db)
        # build bindings from references
        bindings = []
        if query.references
          query.references.each do |reference|
            bindings << @row[reference]
          end
        end
        # query
        qry = query.query.gsub('&apos;',"'").gsub('&quot;','"')  # replace single and double quotes that rexml substituted out.
        if bindings.empty?
          rows = db.connection.select_all(qry)
        else
          rows = db.connection.select_all(qry, *bindings)
        end
        result_rows = []
        rows.each do |row|
          result_rows << Row.new(query.name, row, query.attributes)
        end
        result_rows.each do |row|
          self << row
        end
        return result_rows
      end
      
      # this is a mesh builder which returns this Row (self) as xml
      def xml
        base = REXML::Element.new(@name)
        if @row.class == DBI::Row  # only if we have a row otherwise return an empty xml node
          # prime
          context = nil
          rowcontext = base
          # loop through each column
          @row.each_with_name do |val, colpath|
            context = rowcontext                          # start at the top of the row for each column
            parents = colpath.split('/')                  # split on any path dividers, i.e. parent/parent/child
            child = parents.pop                           # get the child off the parents
            # loop through all the parents
            parents.each.each do |p|
              found = REXML::XPath.first(context, p)      # does the element already exist?
              if not found                                # if not...
                el = p.gsub(/[[].*[]]$/,'')               # remove index if there is one
                found = context.add_element(el)           # add the element
              end
              context = found                             # this parent is now our new context
            end
            # do the child (the end of the tree branch)
            if child =~ /^@(.*)/                          # is it labeled an attribute with @?
              context.add_attribute($1, val.to_s)         # add attribute
            elsif @attributes.include?(child)             # or is it in the attributes list?
              context.add_attribute(child, val.to_s)      # add attribute
            else
              found = REXML::XPath.first(context, child)  # does it already exist?
              if not found                                # if not...
                el = child.gsub(/[[].*[]]$/,'')           # remove index if there is one
                found = context.add_element(el)           # add the element
              end
              context = found                             # the child is now our new context
              context.add_text(val.to_s)                  # insert the text node as val
            end
          end
        end
        return base
      end  # def
      
      #
      def dump
        "(DBXML::XQuery::Row) name:#{name} row:#{row}"
      end
      
    end
    
    # REXML stream parser engine
    class SQLiX_Listener
    
      attr_reader :xml
  
      #
      def initialize(db, seeds={})
        @root = nil
        @dbi = db
        @nil_row = Row.new('__container__', seeds, nil)
        @parent_stack = [[@nil_row]]
        @at_start = true
      end
    
      # -- build query tree, listener required methods
      
      def xmldecl ver, enc, stand
        # ignore xml declaration
      end
      
      def doctype(name, *contents)
        # ignore doctype
      end
      
      def instruction name, instruction
        # ignore any instructions (for now)
      end
      
      def comment comment
        # ignore comments
      end

      def tag_start name, attributes
        
        if not @root
          @root = name  # get the root element out of the way
        else
          
          # -- build query object
          query = nil
          references = nil
          if attributes
            attributes.each do |a|
              case a[0]
              when 'query'                                                                   # the sql query
                query = a[1].strip                                                           # clean of any whitespace
                if query.empty?
                  query = nil                                                                # if empty make nil
                end
              when 'references'                                                              # reference bindings
                references = a[1].strip.split(',').collect { |reference| reference.strip }   # clean each one of any white space
                if references.empty? 
                  references = nil                                                           # if empty make nil
                end
              when 'attributes'                                                              # attrtibutal fields
                attributes = a[1].strip.split(',').collect { |attribute| attribute.strip }   # clean each one of any white space
                if attributes.empty? 
                  attributes = nil                                                           # if empty make nil
                end
              else
                raise "Unknown row tag attribute, #{a[0]}"
              end
            end
          end
          if not query  # there must at least be a query attribute
            raise "Row tag without query, #{name}"
          end
          
          query = Query.new(name, query, references, attributes)  # query is tranformed into a Query object
  
          r = []
          @parent_stack.last.each do |row|
            r << row.q!(query, @dbi)
          end
          r.flatten!
          @parent_stack.push(r)
          
          @at_start = true

        end

      end
        
        
      def tag_end name
        @parent_stack.pop
        @at_start = false
      end
      
      
      def text value
        # ignore any text
      end
    
    
      def method_missing(a, *b)
        raise "Method Missing: #{a}, #{b}"
      end
      

      # build xml document

      #
      def build_document
        @xml = build_recurse(@nil_row)  # begin with nil node
        return @xml
      end
    
      #
      def build_recurse(row_branch)
        if row_branch.children.empty?
          # no children, this is the end of the recursive road
          return row_branch.xml
        else
          parent_xml = row_branch.xml
          row_branch.children.each do |sub_row_branch|
            parent_xml.add_element(build_recurse(sub_row_branch))
          end
          return parent_xml
        end
      end
      
    end  # SQLiX_Listener
    
  end  # SQLiX
  
end  # XMLToolKit

