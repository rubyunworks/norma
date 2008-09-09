
module DataBob

  # Errors
  class AdapterError < Exception #:nodoc:
  end
  class AdapterNotSpecified < AdapterError # :nodoc:
  end
  class AdapterNotFound < AdapterError # :nodoc:
  end
  class ConnectionNotEstablished < AdapterError #:nodoc:
  end
  class ConnectionFailed < AdapterError #:nodoc:
  end

  # Behavior for establishing a connection with a database.
  module DatabaseConnection
  
    # Would this be useful as an independent "service" module too?
    #extend self
  
    attr_reader :config
    attr_accessor :connection  # why is this here?
    
    def connection #:nodoc:
      Thread.current['connection'] ||= retrieve_connection
      Thread.current['connection']
    end
    
    def connected?
      !Thread.current['connection'].nil?
    end 
    
    # Establishes the connection to the database. Accepts a hash as input where
    # the :adapter key must be specified with the name of a database adapter (in lower-case)
    # example for regular databases (MySQL, Postgresql, etc):
    #
    #   establish_connection(
    #     :adapter  => "mysql",
    #     :host     => "localhost",
    #     :username => "myuser",
    #     :password => "mypass",
    #     :database => "somedatabase"
    #   )
    #
    # Example for SQLite database:
    #
    #   establish_connection(
    #     :adapter => "sqlite",
    #     :dbfile  => "path/to/dbfile"
    #   )
    #
    # Also accepts keys as strings (for parsing from yaml for example):
    #   establish_connection(
    #     "adapter" => "sqlite",
    #     "dbfile"  => "path/to/dbfile"
    #   )
    #
    # The exceptions AdapterNotSpecified, AdapterNotFound
    # and ArgumentError may be returned on an error.
    def establish_connection(config)
      if config.nil? then raise AdapterNotSpecified end
      config.symbolize_keys
      raise AdapterNotSpecified unless config.key?(:adapter)
      #adapter_method = "#{config[:adapter]}_connection"
      #unless methods.include?(adapter_method) then raise AdapterNotFound end
      raise AdapterNotFound unless Adapters::Available.key?(config[:adapter].intern)
      @config = config
      Thread.current['connection'] = nil
    end
    
    def retrieve_connection #:nodoc:
      raise(ConnectionNotEstablished) if @config.nil?
      #begin
        #send(@adapter_method, @config)
        Adapters::Available[@config[:adapter].intern].connect(@config)
      #rescue Exception => e
      #  raise(ConnectionFailed, e.message)
      #end
    end

  end  # DatabaseConnection
  
end  # AbstractAdapter

