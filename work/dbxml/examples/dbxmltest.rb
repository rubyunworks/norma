require 'rexml/document'
require 'xmltoolkit/dbxml/dbxml'

xdb = DBXML.new

xml_file = File.new("mydata.xml")
xml_dox = Document.new(xml_file)
xdb.insert('test', xml_dox)

#xml_record = xdb.select('test', 2)
#puts xml_record
#puts xml_record.type
