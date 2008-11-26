module Norma
  ### Base class for database adapters.
  ### This class is modeled for a minimal Postgresql
  ### adapter as a reference point.
  class Database

    ### Database Interface Error class
    class InterfaceError < TypeError ; end

    #
    CORE = [String, Symbol, Fixnum, Float, Range, Time, Array, Hash]

    #
    def initialize(connection, logger = nil)
      @connection = connection
      @logger = logger
      @runtime = 0
      @cache = {}
    end

    def bootstrap
      raise InterfaceError, "no bootstrap method"
    end

    # Read a record.
    def read(id, object=nil)
      raise InterfaceError, "no read method"
    end

    # Save (or insert) a record.
    def save(klass, obj, id=nil)
      raise InterfaceError, "no save method"
    end

    # Delete a record.
    def delete(klass, id)
      raise InterfaceError, "no save method"
    end

    # Select records.
    def select(&block)
      raise InterfaceError, "no select method"
    end

    # Return next available object record index.
    def mint_id
      raise InterfaceError, "no mint_id method"
    end

    # Load a record. This calls read, but caches
    # the result. This is very important, otherwise
    # an object will be loaded more than once.
    #
    def load( id, object=nil )
      @cache[id] ||= read(id)
    end

    #
    def update_sql(object)
      update_object_sql(object) + update_class_sql(object)
    end

    #
    def insert_sql(object)
      insert_object_sql(object) + insert_class_sql(object)
    end

    #
    def update_object_sql(object)
      sql = ''
      sql << %|UPDATE obj\n|
      sql << %|SET class='#{object.class}'\n|
      sql << %|WHERE id=#{object.record_id}|
      sql << ';'
      sql
    end

    #
    def insert_object_sql(object)
      sql = ''
      sql << %|INSERT INTO obj |
      sql << %|(id, class)\n|
      sql << %|VALUES (#{object.record_id}, '#{object.class}')|
      sql << ';'
      sql
    end

    #
    def update_class_sql(object)
      return '' unless respond_to?("sql#{object.class}")
      sql = ''
      sql << %|UPDATE obj#{object.class}\n|
      sql << %|SET |
      sql << send("sql#{object.class}").map{|k,v|"#{k}=#{v}"}.join(' ')
      sql << %|\nWHERE id=#{object.id}|
      sql << ';'
      sql
    end

    #
    def insert_class_sql(object)
      return '' unless respond_to?("sql#{object.class}")

      atts = send("sql#{object.class}", object)        
      keys = atts.keys.join(',')
      vals = atts.values.join(',')

      sql = ''
      sql << %|INSERT INTO obj#{object.class} |
      sql << %|(id, #{keys})\n|
      sql << %|VALUES (#{object.record_id}, #{vals})|
      sql << ';'
      sql
    end

    #
    def update_ivar_sql(object, field, value)
      name = field.sub(/^@/,'')
      sql = ''
      sql << %|UPDATE ivar\n|
      sql << %|SET val_id=#{value.record_id}\n|
      sql << %|WHERE obj_id=#{object.record_id} AND name='#{name}'|
      sql << ';'
    end

    #
    def insert_ivar_sql(object, field, value)
      name = field.sub(/^@/,'')
      sql = ''
      sql << %|INSERT INTO ivar |
      sql << %|(obj_id, val_id, name)\n|
      sql << %|VALUES (#{object.record_id}, #{value.record_id}, '#{name}')|
      sql << ';'
    end

    ####################
    # Object -> Record #
    ####################

    #
    #def sqlObject(object)
    #  object.inspect
    #end

    def sqlSymbol(object)
      { :value => object.to_s.inspect }
    end

    def sqlString(object)
      { :value => object.inspect }
    end

    def sqlFixnum(object)
      { :value => object.to_i }
    end

    def sqlFloat(object)
      { :value => object.to_f }
    end

    def sqlRange(object)
      { :begins    => object.begin,
        :ends      => object.end,
        :exclusive => object.exclude_end? }
    end

    def sqlTime(object)
      { :value => object.strftime('%Y-%m-%d %H:%M:%S').inspect }
    end

    def sqlArray(object)
      { :values => "'{" + object.map{|o|"#{o.record_id}"}.join(',') + "}'" }
    end

    def sqlHash(object)
      { :keys => object.keys,
        :values => object.values 
      }
    end

    ####################
    # Record -> Object #
    ####################

    def newSymbol(rec)
      rec[1].to_sym
    end

    #
    def newString(rec)
      rec[1]
    end

    def newFixnum(rec)
      Integer(rec[1])
    end

    def newFloat(rec)
      Float(rec[1])
    end

    def newRange(rec)
      Range.new(rec[1], rec[2], rec[3])
    end

    def newTime(rec)
      rec[1]  # TODO: parse time string
    end

    def newArray(rec)
      ary = []
      rec[1].scan(/\d+/).each do |i|
        ary << load(i.to_i)
      end
      ary
    end

    def newHash(rec)
      keys = []
      rec[1].scan(/\d+/).each do |id|
        keys << load(id.to_i)
      end
      vals = []
      rec[2].scan(/\d+/).each do |id|
        vals << load(id.to_i)
      end
      Hash[*keys.zip(vals)]
    end

  end # class Database

end # module Norma

