

  class X

    sql_mapping( 'atable', :record_id => :record_id ) {
      field :x => :x
    }

    def addresses
      ObjectSpace.each_object( Address ) { |o| o.x_id === id }
    end

  end


  # At the moment this differes slightly from standard
  # SQL in that each column definition is expected to
  # be on a new line, rather than separated by commas.
  # That just makes it easier to parse for this initial
  # version.

  def attr_sql( str )
    str.strip!
    i = index(' ')
    name, str = str[0...i], str[i..-1]

    # primary key?
    if /primary key/i ~= str
      primary_key = true
      str.gsub!(/primary key/i, '')
    end
  end