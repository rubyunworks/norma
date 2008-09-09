# XMLToolKit - DBXML
# Thomas Sawyer (c)2002, LGPL

DBDSN = 'dbi:Pg:zenacct:192.168.0.201'
DBUSER = 'postgres'
DBPASS = 'postgres'

require "rexml/document"
require "dbi"

module XMLToolKit

  class DBXML
  
    # Constructor
    def initialize
      @dsn = DBDSN
      @user = DUSER
      @pass = DPASS
      @dbh = DBI.connect(@dsn, @user, @pass)
    end
    
    # Create an XML Database Table
    def create_xmltable table_name
      # create specialty xml table
      sql = "CREATE TABLE #{table_name} ("
      sql += " record INT SERIAL PRIMARY KEY,"
      sql += " content text DEFAULT '',"
      sql += " );"
      rpc = @dbh.do(sql)
      # create cooresponding tracking table
      sql = "CREATE TABLE #{table_name}_track ("
      sql += " record INT SERIAL PRIMARY KEY,"
      sql += " reference INT REFERENCES #{table_name}(record),"
      sql += " type VARCHAR(1) DEFAULT '',"
      sql += " name TEXT DEFAULT '',"
      sql += " content TEXT DEFAULT '',"
      sql += " );"
      rpc = @dbh.do(sql)
    end
    
    # Drop an XML Database Table
    def drop_xmltable table_name
      sql = "DROP TABLE #{table_name};"
      rpc = @dbh.do(sql)
      sql = "DROP TABLE #{table_name}_track;"
      rpc = @dbh.do(sql)
    end
    
    # Insert XML Document into XML Database Table
    def insert_all(table_name, xml_document)
      # prep sql templates
      sql = "INSERT INTO #{table_name} (content) VALUES (?);"
      insert_tmpl = @dbh.prepare(sql)
      sql = "UPDATE #{table_name} SET content=? WHERE record=?;"
      update_tmpl = @dbh.prepare(sql)
      #prepare xml document
      parse_array = parse_input(xml_document)
      # insert each row
      parse_array.each do |r|
        record = r['record']
        content = r['content']
        puts record
        puts content
        if record
          update_tmpl.execute(content, record)
        else
          insert_tmpl.execute(content)
        end
      end
      update_tmpl.finish
      insert_tmpl.finish
    end
    
    # Parse given XML Document into XML Records Array
    def parse_input(xml_document)
      
      temp_string = String.new('')
      temp_hash = Hash.new
      temp_array = Array.new
      
      xml_document.root.elements.each do |element|
        # store record attribute in hash (nil if not present)
        temp_hash['record'] = element.attributes['record']
        # remove record attribute (if present)
        element.delete_attribute('record')
        # store element in hash
        temp_string = ''
        element.write(temp_string)
        temp_hash['content'] = temp_string
        # store hash in array
        temp_array.push temp_hash.dup
      end
      
      # return the array of element contents and record numbers
      return temp_array
      
    end
  
    # Insert XML Record into XML Database Table
    def insert(table_name, xml_record)
      # prep sql templates
      sql = "INSERT INTO #{table_name} (content) VALUES (?);"
      insert_tmpl = @dbh.prepare(sql)
      sql = "UPDATE #{table_name} SET content=? WHERE record=?;"
      update_tmpl = @dbh.prepare(sql)
      #prepare xml record
      record = xml_record.root.element.attributes['record']
      # remove record attribute (if present)
      xml_record.root.element.delete_attribute('record')
      content = ''
      element.write(content)
      # insert row
      puts record
      puts content
      if record
        update_tmpl.execute(content, record)
      else
        insert_tmpl.execute(content)
      end
      update_tmpl.finish
      insert_tmpl.finish
    end
    
    # Select XML Record from Database Table
    def select(table_name, record_number)
      
      sql = "SELECT * FROM #{table_name} WHERE record=#{record_number};"
      r = @dbh.select_one(sql)
      if r
        record = r['record'].to_s
        content = r['content']
      else
        record = nil
        content = nil
      end
      
      xml_record = REXML::Document.new(content)
      xml_record.root.add_attribute('record', record)
      
      return xml_record
      
    end
    
  end

end  # XMLToolKit
