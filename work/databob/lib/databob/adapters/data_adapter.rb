
module DataBob::Adapters # :nodoc:

  # All the concrete database adapters follow the interface laid down in this class.
  class DataAdapter

    class StatementInvalid < Exception #:nodoc:
    end

    @@row_even = true

    include Benchmark

    # Is this what's expected?
    class << self
      attr_accessor :logger
    end

    def initialize(connection, logger = nil) # :nodoc:
      @connection = connection
      @logger = logger
      @runtime = 0
    end

    # Returns an array of record hashes with the column names as a keys and fields as values.
    def select_all(sql, name = nil) end

    # Returns a record hash with the column names as a keys and fields as values.
    def select_one(sql, name = nil) end

    # Returns an array of column objects for the table specified by +table_name+.
    def columns(table_name, name = nil) end

    # Returns the last auto-generated ID from the affected table.
    def insert(sql, name = nil) end

    # Executes the update statement.
    def update(sql, name = nil) end

    # Executes the delete statement.
    def delete(sql, name = nil) end

    def reset_runtime # :nodoc:
      rt = @runtime
      @runtime = 0
      return rt
    end

    # Begins the transaction (and turns off auto-committing).
    def begin_db_transaction()    end

    # Commits the transaction (and turns on auto-committing).
    def commit_db_transaction()   end

    # Rollsback the transaction (and turns on auto-committing).
    # Must be done if the transaction block raises an exception or returns false.
    def rollback_db_transaction() end

    def quote(value, column = nil)
      case value
        when String  # (for ruby-mode)
          "'" << value.gsub( %r{\\},'\&\&' ).gsub(%r{'}, %{''}) << "'"
        when NilClass
          "NULL"
        when TrueClass
          (column and column.type == :boolean ? "'t'" : "1")
        when FalseClass
          (column and column.type == :boolean ? "'f'" : "0")
        when Float, Fixnum, Date
          "'#{value.to_s}'"
        when Time, DateTime
          "'#{value.strftime("%Y-%m-%d %H:%M:%S")}'"
        else
          "'#{value.to_yaml}'"
      end
    end

    # Returns a string of the CREATE TABLE SQL statements for recreating
    # the entire structure of the database.
    def structure_dump() end

    protected  #-----------------------------------------------------------

    def log(sql, name, connection, &action)
      begin
        if @logger.nil?
          action.call(connection)
        else
          bm = measure { action.call(connection) }
          @runtime += bm.real
          log_info(sql, name, bm.real)
        end
      rescue => e
        raise StatementInvalid, "#{e.message}: #{sql}"
      end
    end

    def log_info(sql, name, runtime)
      return if @logger.nil?
      @logger.info(
        format_log_entry(
          "#{name.nil? ? "SQL" : name} (#{sprintf("%f", runtime)})",
          sql.gsub(/ +/, " ")
        )
      )
    end

    def format_log_entry(message, dump = nil)
      if @@row_even then
        @@row_even = false; caller_color = "1;32"; message_color = "4;33"; dump_color = "1;37"
      else
        @@row_even = true; caller_color = "1;36"; message_color = "4;35"; dump_color = "0;37"
      end
      log_entry =  "  \e[#{message_color}m#{message}\e[m"
      log_entry << "  \e[#{dump_color}m%s\e[m" % dump if dump.kind_of?(String) && !dump.nil?
      log_entry << "  \e[#{dump_color}m%p\e[m" % dump if !dump.kind_of?(String) && !dump.nil?
      log_entry
    end

  end

  # add this adapter to the available list
  # initializing the Available module constant
  Available = {:null => DataAdapter}

end
