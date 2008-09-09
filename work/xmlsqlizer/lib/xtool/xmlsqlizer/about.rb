# XMLSqlizer/Ruby - About

module XMLSqlizer
  TITLE = "XMLSqlizer/Ruby"
	RELEASE = "02.06.04"
	STATUS = "BETA"
	AUTHOR = "Thomas Sawyer"
	EMAIL = "transami@transami.net"
	# This taken almost directly from Jim Menard's NQXML.  Good idea, Jim.
	Package = "#{TITLE}"
	Version = "v#{RELEASE} #{STATUS}"
	Copyright = "Copyright © 2002 #{AUTHOR}, #{EMAIL}"
end

# Write about info to standerd out
if $0 == __FILE__
	puts XMLSqlizer::Package
	puts XMLSqlizer::Version
	puts XMLSqlizer::Copyright
end