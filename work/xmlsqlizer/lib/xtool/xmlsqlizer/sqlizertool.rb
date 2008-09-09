# XMLProof - ProofTool
#
# This is a command line tool for XMLProof's Validator and SQLCreator
#
#   USAGE: prooftool -v xml-document
#    -or-: prooftool -s proof-sheet
#
#     e.g. prooftool -v data.xml
#     -or- prooftool -s test.xps

require 'xmlproof/about'
require 'xmlproof/validator'
require 'xmlproof/sqlcreator'


if $0 == __FILE__

	validoptions = true

	if ARGV.length < 2 or ARGV.length > 3
		validoptions = false
	end

	case ARGV[0]
	when '-v', '-s'
		option = ARGV[0]
	else
		validoptions = false
	end

	if not validoptions
		puts
    puts "#{XMLProof::Package} - Proof Tool"
		puts 
		puts "USAGE: #{$0} -v xml-document"
		puts " -or-: #{$0} -s proof-sheet"
		puts
		puts "  e.g. #{$0} -v data.xml"
		puts "  -or- #{$0} -s test.xps"
    puts
	else

		if option == '-v'
			xml = File.new(ARGV[1])
			validator = XMLProof::Validator.new
			valid = validator.valid?(xml)
			if valid
				puts "GOOD DOCUMENT"
			else
				puts "BAD DOCUMENT"
				validator.errors.each do |e|
					puts "xpath->#{e[0]} \t namespace->#{e[1]} \t error->#{e[2]}"
				end
			end
		elsif option == '-s'
			xps = File.new(ARGV[1])
			sql_creator = XMLProof::SQLCreator.new
			sqls = sql_creator.generate_sqls(xps)
			sqls.each do |statement|
				puts statement
			end
		end
		
	end
	
end

