# column.rb

require 'date'

module DatabaseAdapter

  module ConnectionAdapters
 
    # Common class used by all adapters
    class Column # :nodoc:
  
      attr_reader :name, :default, :type, :limit
      
      # The name should contain the name of the column, such as "name" in "name varchar(250)"
      # The default should contain the type-casted default of the column, such as 1 in "count int(11) DEFAULT 1"
      # The type parameter should either contain :integer, :float, :datetime, :date, :text, or :string
      # The sql_type is just used for extracting the limit, such as 10 in "varchar(10)"
      def initialize(name, default, sql_type = nil)
        @name, @default, @type = name, default, simplified_type(sql_type)
        @limit = extract_limit(sql_type) unless sql_type.nil?
      end
  
      def default
        type_cast(@default)
      end
  
      def klass
        case type
          when :integer       then Fixnum
          when :float         then Float
          when :datetime      then Time
          when :date          then Date
          when :text, :string then String
          when :boolean       then Object
        end
      end
      
      def type_cast(value)
        if value.nil? then return nil end
        case type
          when :string   then value
          when :text     then object_from_yaml(value)
          when :integer  then value.to_i
          when :float    then value.to_f
          when :datetime then string_to_time(value)
          when :date     then string_to_date(value)
          when :boolean  then (value == "t" or value == true ? true : false)
          else value
        end
      end
      
      def human_name
        Base.human_attribute_name(@name)
      end
  
      private
        def object_from_yaml(string)
          if has_yaml_encoding_header?(string)
            begin
              YAML::load(string)
            rescue Exception
              # Apparently wasn't YAML anyway
              string
            end
          else
            string
          end
        end
        
        def has_yaml_encoding_header?(string)
          string[0..3] == "--- "
        end
      
        def string_to_date(string)
          return string if Date === string
          date_array = ParseDate.parsedate(string)
          # treat 0000-00-00 as nil
          Date.new(date_array[0], date_array[1], date_array[2]) rescue nil
        end
        
        def string_to_time(string)
          return string if Time === string
          time_array = ParseDate.parsedate(string).compact
          # treat 0000-00-00 00:00:00 as nil
          Time.local(*time_array) rescue nil
        end
  
        def extract_limit(sql_type)
          $1.to_i if sql_type =~ /\((.*)\)/
        end
  
        def simplified_type(field_type)
          case field_type
            when /int/i
              :integer
            when /float|double|decimal|numeric/i
              :float
            when /datetime/i, /time/i
              :datetime
            when /date/i
              :date
            when /(c|b)lob/i, /text/i
              :text
            when /varchar/i, /char/i, /string/i, /character/i
              :string
            when /boolean/i
              :boolean
          end
        end
      
    end  # Column
  
  end  # ConnectionAdapters
  
end  # DatabaseAdapter
