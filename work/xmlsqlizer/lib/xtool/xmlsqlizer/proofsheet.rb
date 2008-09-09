# XMLProof/Ruby - ProofSheet Related Classes
# Copyright (c) 2002 Thomas Sawyer, Ruby License

require 'rerexml/rerexml'
require 'tomslib/communication'
require 'parsedate'


module XMLProof
	
	# Represents a single parsed proof entry in a tag or attribute
	class Die
	
		attr_reader :cast, :regexp, :sql, :datatype, :default, :null, :unique, :primary_key, :foriegn_key, :references
		
		#
		def initialize(cast, xpath = nil)

			@cast = cast        # the complete die entry from the proofsheet
			@xpath = xpath      # associated xpath, if any otherwise nil

			@regexp = nil       # regular expression before the ::
			@sql = nil          # complete sql create table attribute entry after the ::
			@datatype = nil     # datatype string parsed from the sql
			@default = nil      # default parsed from the sql
			@null = nil         # boolean parsed from the sql
			@unique = nil       # boolean parsed from the sql
			@primary_key = nil  # boolean parsed from the sql
			@foriegn_key = nil  # boolean parsed from the sql
			@references = nil   # table(columns,...) string parsed from the sql
			
			parse
		
		end
	
		# Parses a ProofSheet die entry
		def parse
				
				entry = @cast
				
				# main parse of cast entry
				re = Regexp.new(/^\s*(.*)\s*::\s*(.*)\s*$/)
				md = re.match(entry)
				if md
					regexp = md[1]
					regexp = regexp ? Regexp.new(regexp.reverse.chomp('/').reverse.chomp('/')) : nil  # the chomps remove the /... / deliminators if given
					sql = md[2]
				else
					regexp = nil
					sql = nil
				end
				
				# regexp
				@regexp = regexp        # default regexp is nil (could be "/.*/", but nil speeds things up elsewhere)
				
				# sql
				sql = '' if not sql     # if sql is nil make it an empty string
				if sql.empty?
					@sql = sql = "text"   # default sql
				else
					@sql = sql
				end
				
				# datatype
				@datatype = sql.split(' ')[0].downcase
				# -- to do: check to make sure datatype is a valid type?
				
				# null
				re = Regexp.new(/[NOT NULL|PRIMARY KEY]/, Regexp::IGNORECASE)
				@null = (re.match(sql) ? false : true)
				
				# unique
				re = Regexp.new(/[UNIQUE|PRIMARY KEY]/, Regexp::IGNORECASE)
				@unique = (re.match(sql) ? true : false)
				
				# primary key
				re = Regexp.new(/PRIMARY KEY/, Regexp::IGNORECASE)
				@primary_key = (re.match(sql) ? true : false)
				
				# foreign key
				re = Regexp.new(/FORGEIN KEY/, Regexp::IGNORECASE)
				@foreign_key = (re.match(sql) ? true : false)
				
				# references
				re = Regexp.new(/REFERENCES\s+(['"])(.*?)\1\s+/, Regexp::IGNORECASE)
				md = re.match(sql)
				@references = md ? md[2] : ''
				
        # default
				re = Regexp.new(/DEFAULT\s+(['"]?)(\w+?)\1/, Regexp::IGNORECASE)
				md = re.match(sql)
				if md
          if md[2].downcase == "null"
            if @null
              @default = nil
            else
              raise "Die sets default to null, but is also defined as not null: #{sql}"
            end
          else
            @default = typecast(md[2])
          end
        else
          if @null
            @default = nil
          else
            @default = typecast('')
          end
        end
        
			end
	
			# Returns given text cast to die's datatype
			def typecast(text)
				result = nil
				text = '' if not text  # if text is nil, then text is empty
        case @datatype
        when /bool/
          if text.strip =~ /^(yes|true|1)$/
            result = true
          else
            result = false
          end
        when /int/, /serial/
          if text.strip =~ /^([+]|[-])?\d+$/
            result = text.to_i
          else
            result = 0
          end
        when /float/, /double/
          if text.strip =~ /^([+]|[-])?\d*\.?\d+$/
            result = text.to_f
          else
            result = 0.0
          end
        when /numeric/, /decimal/                 # this currently does not inspect size limits
          if text.strip =~ /^([+]|[-])?\d*\.?\d+$/
            result = text.to_f
          else
            result = 0.0
          end
        when /timestamp/                          # returns string not time object
          pd = ParseDate.parsedate(text)
          if pd[0]
            result = text
          else
            result = '2002-01-01 12:00:00'  #change to current timestamp!!!!
          end
        when /date/                               # returns string not date object
          pd = ParseDate.parsedate(text)
          if pd[0]
            result = text
          else
            result = '2002-01-01'  #change to today's date!!!!
          end
        when /time/                               # returns string not time object
          if text.strip =~ /\d+:\d+/
            result = text
          else
            result = '12:00'  #change to now!!!!!
          end
        when /varchar/                            # this currently does not inspect size limits
          result = text
        when /text/
          result = text
        else
          result = nil				
        end
        return result
			end
			
	end  # Die
	
	
	# Stores a ProosSheet (.xps) parsed into dies and controls
	class ProofSheet
	
		include TomsLib::Communication

		attr_reader :xps, :segment, :namespace_prefix, :namespace_uri, :die, :ctrls_count, :ctrls_order, :ctrls_option, :ctrls_track
	
    # Loads and parses proofsheet schema.
		def initialize(url_or_string, namespace_prefix=nil, namespace_uri=nil, segment=nil)
			
			@xps = fetch_xml(url_or_string)
			@segment = '//' + segment
      
			@namespace_prefix = namespace_prefix  # associated namespace prefix
			@namespace_uri = namespace_uri        # associated namespace uri
			
			@die = {}           #
			@ctrls_count = {}   #
			@ctrls_order = {}   #
			@ctrls_option = {}  #
			@ctrls_track = []   #
			
			parse_proofsheet
			
		end


		# Valid attribute strings are:
		# * regexp      : regular expression before the ::
		# * sql         : complete sql create table attribute entry after the ::
		# * datatype    : datatype string parsed from the sql
		# * null        : boolean parsed from the sql
		# * unique      : boolean parsed from the sql
		# * primary key : boolean parsed from the sql
		# * foriegn key : boolean parsed from the sql
		# * references  : table(columns,...) string parsed from the sql
		
	
		private  # --------------------------------------------

		def parse_proofsheet
			# make sure its a valid proofsheet (.xps) (?)
			# --- not yet implemtented, assumed correct
			@die = load_die_schema                    # load tag and attribute dies
			@ctrls_count = load_count_schema          # load count schema
			@ctrls_order = load_order_schema          # load order schema
			@ctrls_option = load_option_schema        # load option schema
			@ctrls_track = load_track_schema          # load track schema
		end
	
  	# Loads die schema for the given proofsheet
    def load_die_schema
      xps_source = REXML::SourceFactory.create_from(@xps)
      xps_document = REXML::Document.new(xps_source)
      #raise @segment
      if @segment
        xps_document = REXML::XPath.first(xps_document, @segment)
      end
      schema_die = {}
      # load all casted elements
      casted_elements = REXML::XPath.match(xps_document,'//').select do |element|
        proper = false
        ins = element.inherited_namespace
        proper = ((element.has_text?) and (not element.has_elements?) and (ins != "http://www.transami.net/namespace/xmlproof" and ins != "http://transami.net/namespace/xmlproof"))
        proper
      end
      casted_elements.each do |element|
        xpath = element.absolute_xpath.gsub(/^proofsheet\//,'').gsub(/^schema\//,'')  # remove root tag
        cast = element.text.strip
        schema_die[xpath] = Die.new(cast)
      end
      # load all casted attrributes
      casted_attributes = []
      REXML::XPath.each(xps_document,'//[@]') do |element|
        element.attributes.each_attribute do |attribute|
          ins = attribute.inherited_namespace
          proper = (ins != "http://www.transami.net/namespace/xmlproof" and ins != "http://transami.net/namespace/xmlproof")
          casted_attributes << attribute if proper
        end
      end
      casted_attributes.each do |attribute|
        xpath = attribute.absolute_xpath.gsub(/^proofsheet\//,'').gsub(/^schema\//,'')  # remove root tag
        cast = attribute.value.strip
      #puts xpath, cast
        schema_die[xpath] = Die.new(cast)
      end
      return schema_die
    end
    
		# Loads a counting schema for the given proofsheet in the form of { xpath => 'i..n', ... }
		def load_count_schema
			re = Regexp.new(/(\d+)(\.\.\.?)([\d]+|[*]?)/)
			xps_source = REXML::SourceFactory.create_from(@xps)
			xps_document = REXML::Document.new(xps_source)
      if @segment
        xps_document = REXML::XPath.first(xps_document, @segment)
      end
			schema_count = {}
			count_attributed_elements = REXML::XPath.match(xps_document,'//').select do |element|
        proper = false
        if element.attributes.has_key?('count')
          ins = element.attributes.get_attribute('count').inherited_namespace
          proper = (ins == "http://www.transami.net/namespace/xmlproof" or ins == "http://transami.net/namespace/xmlproof")
        end
        proper
      end
      count_attributed_elements.each do |element|
        xpath = element.absolute_xpath.gsub(/^proofsheet\//,'').gsub(/^schema\//,'')  # remove root tag
        # parse range
        range = element.attributes['count']
        md = re.match(range)
        # if good range
        if md
          # continue parsing range
          atleast = md[1].to_i
          if md[3] == "*"      # open ended
            atmost = (1.0/0.0) # infinite
          else
            if md[2] == ".." 
              atmost = md[3].to_i
            else #...
              atmost = md[3].to_i - 1
            end
          end
          # range valid
          if atleast > atmost then
            raise "XMLProof Error: Invalid count range, max is greater then min: #{range}"
          end
        else
          raise "XMLProof Error: Invalid count range: #{range}"
        end
        schema_count[xpath] = Range.new(atleast, atmost)
			end
			return schema_count
		end
		
		# Loads an option schema for the given proofsheet in the form of { group => [ xpath, ... ], ... }
		def load_option_schema
			xps_source = REXML::SourceFactory.create_from(@xps)
			xps_document = REXML::Document.new(xps_source)
      if @segment
        xps_document = REXML::XPath.first(xps_document, @segment)
      end
			schema_option = {}
      option_attributed_elements = REXML::XPath.match(xps_document,'//').select do |element|
        proper = false
        if element.attributes.has_key?('option')
          ins = element.attributes.get_attribute('option').inherited_namespace
          proper = (ins == "http://www.transami.net/namespace/xmlproof" or ins == "http://transami.net/namespace/xmlproof")
        end
        proper
      end
      option_attributed_elements.each do |element|
				xpath = element.absolute_xpath.gsub(/^proofsheet\//,'').gsub(/^schema\//,'')
				group = element.attributes['option']
				schema_option[xpath] = group
			end
			return schema_option
		end
		
		# Loads an order schema for the given proofsheet in the form of { xpath => [ child_element_name, ... ], ... }
		def load_order_schema
			xps_source = REXML::SourceFactory.create_from(@xps)
			xps_document = REXML::Document.new(xps_source)
      if @segment
        xps_document = REXML::XPath.first(xps_document, @segment)
      end
			positive_re = Regexp.new(/(yes|true|1)/, Regexp::IGNORECASE)
      schema_order = {}
      order_attributed_elements = REXML::XPath.match(xps_document,'//').select do |element|
        proper = false
        if element.attributes.has_key?('order')
          ins = element.attributes.get_attribute('order').inherited_namespace
          proper = (ins == "http://www.transami.net/namespace/xmlproof" or ins == "http://transami.net/namespace/xmlproof")
        end
        proper
      end
      order_attributed_elements.each do |element|
        if positive_re.match(element.attributes['order'])
          xpath = element.absolute_xpath.gsub(/^proofsheet\//,'').gsub(/^schema\//,'')
          contains = []
          element.elements.each do |el|
            contains << el.name
          end
          schema_order[xpath] = contains
        end
			end
			return schema_order
		end
		
		# Loads a tracking schema for the given proofsheet in the form of [ xpath, ... ]
		def load_track_schema
			xps_source = REXML::SourceFactory.create_from(@xps)
			xps_document = REXML::Document.new(xps_source)
      if @segment
        xps_document = REXML::XPath.first(xps_document, @segment)
      end
			positive_re = Regexp.new(/(yes|true|1)/, Regexp::IGNORECASE)
      schema_track = []
			track_attributed_elements = REXML::XPath.match(xps_document,'//').select do |element|
        proper = false
        if element.attributes.has_key?('track')
          ins = element.attributes.get_attribute('track').inherited_namespace
          proper = (ins == "http://www.transami.net/namespace/xmlproof" or ins == "http://transami.net/namespace/xmlproof")
        end
        proper
      end
      track_attributed_elements.each do |element|
        if positive_re.match(element.attributes['track'])
          xpath = element.absolute_xpath.gsub(/^proofsheet\//,'').gsub(/^schema\//,'')
          schema_track << xpath
        end
			end
			return schema_track
		end
		
	end  # ProofSheet


	# Stores a collection of ProofSheets
	class ProofSet < Array
		
		# Adds a ProofSheet to the ProofSet
		def <<(proofsheet)
			if proofsheet.is_a?(ProofSheet)
				super
			else
				raise "ProofSet can only contain ProofSheets, not: #{proofsheet.type}"
			end
		end
		
		# Adds a ProofSheet to the ProofSet
		def push(proofsheet)
			if proofsheet.is_a?(ProofSheet)
				super
			else
				raise "ProofSet can only contain ProofSheets, not: #{proofsheet.type}"
			end
		end
		
		# Returns a proofsheet if by index number or an array of proofsheets if by namespace
		def [](index_or_ns)
			if index_or_ns.is_a?(String)
				# lookup proofsheets by namespace
				self.select { |ps| ps.namesapce_uri == index_or_ns } 
			else
				super
			end
		end
		
		# Returns the first matching die for a given proofsheet index or namespace and xpath
		def die(index_or_ns, xpath)
      if index_or_ns.is_a?(String)
				# lookup proofsheets by namespace
				proofsheets = self.select { |ps| ps.namespace_uri == index_or_ns } 
			else
				proofsheets = [ self[index_or_ns] ]  # lookup by index
			end
			proofsheets.each do |ps|
				if ps.die[xpath]
					return ps.die[xpath]  # return first matching die
				end
			end
			return nil
		end
		
		# Returns the first matching count control attributation for a given namespace and xpath
		def count(index_or_ns, xpath)
			if index_or_ns.is_a?(String)
				# lookup proofsheets by namespace prefix
				proofsheets = self.select { |ps| ps.namespace_uri == index_or_ns } 
			else
				proofsheets = [ self[index_or_ns] ]
			end
			proofsheets.each do |ps|
				if ps.ctrls_count[xpath]
					return ps.ctrl_count[xpath]  # return first matching count
				end
			end
			return nil
		end
		
		# Returns the first matching option control attributation for a given namespace and xpath
		def option(index_or_ns, xpath)
			if index_or_ns.is_a?(String)
				# lookup proofsheets by namespace prefix
				proofsheets = self.select { |ps| ps.namespace_uri == index_or_ns } 
			else
				proofsheets = [ self[index_or_ns] ]
			end
			proofsheets.each do |ps|
				if ps.ctrls_option[xpath]
					return ps.ctrls_option[xpath]  # return first matching option
				end
			end
			return nil
		end
		
		# Returns the first matching order control attributation for a given namespace and xpath
		def order(index_or_ns, xpath)
			if index_or_ns.is_a?(String)
				# lookup proofsheets by namespace prefix
				proofsheets = self.select { |ps| ps.namespace_uri == index_or_ns } 
			else
				proofsheets = [ self[index_or_ns] ]
			end
			proofsheets.each do |ps|
				if ps.ctrls_order[xpath]
					return ps.ctrls_order[xpath]  # return first matching order
				end
			end
			return nil
		end
		
		# Returns the first matching track control attributation for a given namespace and xpath
		def track(index_or_ns, xpath)
			if index_or_ns.is_a?(String)
				# lookup proofsheets by namespace prefix
				proofsheets = self.select { |ps| ps.namespace_uri == index_or_ns } 
			else
				proofsheets = [ self[index_or_ns] ]
			end
			proofsheets.each do |ps|
				if ps.ctrls_track[xpath]
					return ps.ctrls_track[xpath]  # return first matching option
				end
			end
			return nil
		end
		
	end
		
	
	# Taks an xml document and collects the proofsheets it refers to internally
	class Document_ProofSet < ProofSet
	
		def initialize(xml_document)
			@xml_document = xml_document               # REXML::Document for which to build ProofSet
			@namespace_instructions = load_namespaces  # load namespace instrunctions hash
			@schema_instructions = load_schemas        # load schema instructions array
			super()
			load_proofset                              # load the ProofSet
		end
	
		# Loads the namespace xml processing instruction entities. (This is a non-standard notation!)
		def load_namespaces
			namespace_instructions = {}
			ns_pi_entities = @xml_document.find_all { |i| i.is_a? REXML::Instruction and i.target == 'xml:ns' }
			ns_pi_entities.each do |i|
				if not (i.attributes.has_key?('name') or i.attributes.has_key?('prefix'))
					raise "Namespace instruction missing required name or prefix attribute."
				elsif not (i.attributes.has_key?('space') or i.attributes.has_key?('uri'))
					raise "Namespace instruction missing required space or uri attribute."
				else
					n = i.attributes.has_key?('name') ? i.attributes['name'] : i.attributes['prefix']
					s = i.attributes.has_key?('space') ? i.attributes['space'] : i.attributes['uri']
					namespace_instructions[n] = s
				end
			end
			return namespace_instructions
		end
		
		# Loads the schema xml processing instruction entities. (This is a non-standard notation!)
		def load_schemas
			schema_instructions = []
			schema_pi_entities = @xml_document.find_all { |i| i.is_a? REXML::Instruction and i.target == 'xml:schema' }
			schema_pi_entities.each do |i|
				if not i.attributes.has_key?('namespace')
					raise "Schema instruction missing required namespace attribute."
				elsif not i.attributes.has_key?('type')
					raise "Schema instruction missing required type attribute."
				elsif not i.attributes.has_key?('url')
					raise "Schema instruction missing required url attribute."
				else
					schema_ns = i.attributes['namespace']
					schema_type = i.attributes['type']
					schema_url = i.attributes['url']
          schema_segment = i.attributes['segment']
					schema_instructions << [ schema_ns, schema_type, schema_url, schema_segment ]
				end
			end
			return schema_instructions
		end
		
		# Loads the documents related proofseets as given by the processing instructions.
		def load_proofset
			@schema_instructions.each do |si|
				schema_ns = si[0]
				if @namespace_instructions.has_key?(schema_ns)
          schema_name = schema_ns
          schema_space = @namespace_instructions[schema_ns]
        elsif @namespace_instructions.has_value?(schema_ns)
          schema_name = @namespace_instructions.index(schema_ns)
          schema_space = schema_ns
        else
					raise "Schema instruction does not reference a give namespace: #{schema_ns}."
				end
				schema_type = si[1].downcase
				schema_url = si[2]
        schema_segment = si[3]
				if schema_type == "xmlproof"  # be sure we only get relavent schema types
					self << ProofSheet.new(schema_url, schema_name, schema_space, schema_segment)
				end
			end
		end
		
	end

end # XMLProof
