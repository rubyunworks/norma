
# XMLSQL
# Thomas Sawyer (c)2002


require "rexml/document"
require "dbi"

include REXML


class XMLSQL

	# Constructor
	def initialize
		@dsn = 'dbi:Pg:xen:silver'
		@user = 'postgres'
		@pass = 'postgres'
		@dbh = DBI.connect(@dsn, @user, @pass)
	end
	
	# Create an XML Database Table
	def create_xmltable table_name
		# create specialty xml table
		sql = "CREATE TABLE #{table_name} ("
		sql += " id int PRIMARY KEY,"
		sql += " docno int DEFAULT 0,"
		sql += " sort int DEFAULT 0,"
		sql += " depth int DEFAULT 0,"
		sql += " path text DEFAULT '',"
		sql += " content text DEFAULT '',"
		sql += " attribute bool DEFAULT FALSE"
		sql += " );"
		rpc = @dbh.do(sql)
		# create document number sequence for this table
		sql = "CREATE SEQUENCE #{table_name}_docno_seq;"
		rpc = @dbh.do(sql)
	end
	
	# Drop an XML Database Table
	def drop_xmltable table_name
		sql = "DROP TABLE #{table_name};"
		rpc = @dbh.do(sql)
	end
	
	# Insert New XML Document into Database Table
	def insert_xmldocument(table_name, xml_doc)
		# prep sql template
		sql = "INSERT INTO #{table_name} (docno, sort, depth, path, content, attribute) VALUES (?, ?, ?, ?, ?, ?);"
		sth = @dbh.prepare(sql)
		# translate xml
		parse_array = parse_xml(xml_doc)
		# fetch a document no for this xml record
		docno = fetch_docno(table_name)
		# insert each row
		parse_array.each do |r|
			sort = r['sort']
			depth = r['depth']
			path = r['path']
			content = r['content']
			attribute = r['attribute']
			sth.execute(docno, sort, depth, path, content, attribute)
		end
		sth.finish
	end
	
	def parse_xml(xml_doc)
		# translate xml
		xml_listener = XMLSQLListener.new
		xml_source = SourceFactory.create_from(xml_doc)
		Document.parse_stream(xml_source, xml_listener)
		return xml_listener.parse
	end

	def fetch_docno(table_name)
		sql = "SELECT nextval('#{table_name}_docno_seq');"
		row = @dbh.select_one(sql)
		return row[0]
	end

	# Select XML Document from Database Table
	def select_xmldocument(table_name, doc_no)
		sql = "SELECT * FROM #{table_name} WHERE docno=#{doc_no} ORDER BY sort;"
		sth = @dbh.execute(sql)
		sth.fetch do |r|
			temp_hash['sort'] = r['sort']
			temp_hash['depth'] = r['depth']
			temp_hash['path'] = r['path']
			temp_hash['content'] = r['content']
			temp_hash['attribute'] = r['attribute']
			temp_array.push temp_hash.dup
		end
		sth.finish
		xml_speaker = XMLSQLSpeaker.new(temp_array)
		return xml_speaker.parse
	end
	
end


class XMLSQLListener

	def initialize
		@attribute_hash = Hash.new()
		@element_hash = Hash.new()
		@row_array = Array.new()
		@path = ''
		@sort = 0
		@depth = 0
	end
	
	def push_row(i_hash)
		new_hash = i_hash.dup
		@row_array.push new_hash
	end
	
	def tag_start(name, attrs)
		
		@path += '/' + name
		@depth += 1
		
		attrs.each do |a|
			@sort += 1
			@attribute_hash['sort'] = @sort
			@attribute_hash['depth'] = @depth + 1
			@attribute_hash['path'] = @path + '/' + a[0]
			@attribute_hash['content'] = a[1]
			@attribute_hash['attribute'] = true
			push_row @attribute_hash
			@attribute_hash.clear
		end
		
	end

	def text(content)
		clean_content = content.strip
		if not clean_content.empty?
			@sort += 1
			@element_hash['sort'] = @sort
			@element_hash['depth'] = @depth
			@element_hash['path'] = @path
			@element_hash['content'] = clean_content
			@element_hash['attribute'] = false
			push_row @element_hash
			@element_hash.clear
		end
	end

	def tag_end(name)
		# drop last branch of path
		re = Regexp.new('/\w*$')
		@path = @path.sub(re,'')
		# move to a higher level
		@depth -= 1
	end

	def parse
		return @row_array
	end
		
	def debug_output
		@row_array.each do |r|
			r.each do |k,v|
				puts k
				puts v
			end
		end
	end
	
end


class XMLSQLSpeaker

	def initialize(parse_array)
		@row_array = parse_array
	end

	def parse
		@row_array.each do |r|
			r.each do |k,v|
				puts "#{k}=#{v}"
			end
			puts "\n"
		end
	end
	
end
