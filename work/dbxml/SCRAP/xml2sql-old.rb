require "rexml/document"
include REXML

class RowBuilderListener

	def initialize
		@attribute_hash = Hash.new()
		@element_hash = Hash.new()
		@row_array = Array.new()
		@path = ''
		@sort = 0
		@depth = 0
	end
	
	def push_row i_hash
		new_hash = i_hash.dup
		@row_array.push new_hash
	end
	
	def tag_start name, attrs
		
		@path += '/' + name
		@depth += 1
		
		attrs.each do |a|
			@sort += 1
			@attribute_hash['path'] = @path + '/' + a[0]
			@attribute_hash['attribute'] = true
			@attribute_hash['content'] = a[1]
			@attribute_hash['sort'] = @sort
			@attribute_hash['depth'] = @depth + 1
			push_row @attribute_hash
			@attribute_hash.clear
		end
		
	end

	def text content
		clean_content = content.strip
		if not clean_content.empty?
			@sort += 1
			@element_hash['path'] = @path
			@element_hash['attribute'] = false
			@element_hash['content'] = clean_content
			@element_hash['sort'] = @sort
			@element_hash['depth'] = @depth
			push_row @element_hash
			@element_hash.clear
		end
	end

	def tag_end name
		# drop last branch of path
		re = Regexp.new('/\w*$')
		@path = @path.sub(re,'')
		# move to a higher level
		@depth -= 1
	end

	def make_sql
		table = 'test'
		sql_key = ''
		sql_val = ''
		sql = ''
		@row_array.each do |r|
			r.each do |k,v|
				sql_key += "#{k},"
				if k == 'path' or k == 'content'
					sql_val += "'#{v}',"
				else
					sql_val += "#{v},"
				end
			end
			sql_key.chop!
			sql_val.chop!
			sql += "INSERT INTO #{table} (#{sql_key}) VALUES (#{sql_val});\n"
			sql_key = ''
			sql_val = ''
		end
		puts sql
	end

	def show_array
		@row_array.each do |r|
			r.each do |k,v|
				puts "#{k}=#{v}"
			end
			puts "\n"
		end
	end
	
end

listener = RowBuilderListener.new
xmlfile = File.new("mydoc.xml")
source = SourceFactory.create_from(xmlfile)

Document.parse_stream(source, listener)

listener.show_array
listener.make_sql
