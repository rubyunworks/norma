# XMLToolKit - SQLiX Tool
# Copyright (c)2002 Thomas Sawyer, LGPL

DBDSN = 'dbi:Pg:zenacct:192.168.0.201'
DBUSER = 'postgres'
DBPASS = 'postgres'

require 'xmltoolkit/sqlix'
require 'xmltoolkit/prettyxml'

# command line operation (testing purposes only)
if $0 == __FILE__

	$debug = true

	if ARGV.length == 0 or ARGV.length > 1
    ag = nil
	else
		ag = ARGV[0]
	end

  if ag
	
    sql = File.new(ag)
    
		six = XMLToolKit::SQLiX.new(DBDSN, DBUSER, DBPASS)
		out = six.transform(sql)
    puts XMLToolKit::PrettyXML.pretty(out)
	
	else

    puts
    puts "XMLToolKit::SQLiX - sqlixtool.rb"
		puts "Copyright (c) Thomas Sawyer, Ruby License"
    puts
    puts "USAGE: #{$0} file "
		puts "  e.g. #{$0} query1.xml"
    puts
    
	end

end
