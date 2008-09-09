
require 'yaml'
require 'open-uri'
require 'rooms/store'

require 'facets/more/recorder'  # CHANGE!


module ROOMS

  class YamlStore < Store

    def self.connect( config )

      if config.has_key?(:database)
        database = config[:database]
      else
        raise ArgumentError, "No database specified. Missing argument: database."
      end

      location = config[:location] || "~/rooms/#{database}"

      unless File.directory?( location )
        raise "No store directory at #{location}"
      end

      self.class.new( location )
    end

    def initialize( connection )
      super
      @location = connection
      @tables = {}
    end


    attr :location

    def config
      { :database => @connection.basename,
        :location => @connection.dirname
      }
    end

    def uri
      opts = config.collect{ |k,v| "#{k}=#{v}" }
      "yaml://#{opts.join('&')}"
    end

    def uri
      "yaml:#{@location}"
    end

    def load( klass, recid, obj=nil )
      prime(klass) unless @tables.key?(klass)
      data = @tables[klass].load(recid)
      objectify( data, klass, obj )
    end

    def save( klass, obj, recid=nil )
      prime(klass) unless @tables.key?(klass)
      data = datify( obj )
      @tables[klass].save( data, recid )
    end

    def delete( klass, recid=nil )
      return nil unless @tables.key?(klass)
      @tables[klass].delete( recid )
    end

    def select( klass, &block )
      prime(klass) unless @tables.key?(klass)
      @tables[klass].select( &block )
    end

    def index( klass )
      prime(klass) unless @tables.key?(klass)
      @tables[klass].index
    end

  private

    def prime(klass)
      @tables[klass] = Table.new(klass, self)
      cache(klass)
    end

    def cache(klass)
      @tables[klass].cache
    end

    ###############
    # Table Class #
    ###############

    class Table

      def initialize( klass, store )
        @klass = klass
        @store = store
        @location = File.join( store.location, klass.name.pathize )
        @records = {}
      end

      def load( recid )
        @records[ recid ]
      end

      def save( data, recid=nil )
        recid ||= @next_index
        path = File.join( @location, "#{recid}.yml" )
        output = data.to_h.to_yaml
        File.open( path, "w+" ) { |f| f << output }
        if recid == @next_index
          @records[recid] = data
          @next_index += 1
        end
        recid
      end

      def delete( recid )
        @records.delete(recid)
        # remove file (move to trashbin)
        path = File.join( @location, "#{recid}.yml" )
        FileUtil.mv( path, File.join( @store.location, klass.name.pathize, '_trash', "#{recid}.yml" ) )
        recid
      end

      def select( &block )
        # this is to enusre it follows specs
        r = block.call( Recorder.new )
        # actual selection
        @records.values.select( &block )
      end

      def index
        @records.keys.sort
      end

      # loads in all records (this store is 100% memory based)

      def cache
        Dir.chdir( @location ) do
          #prime unless File.file?('0.yml')
          primer = YAML::load(File.new('0.yml'))
          @recordkeys = primer.keys
          @structclass = Struct.new(*@recordkeys)
          recs = Dir.glob('*.yml')
          recs.each do |f|
            data = YAML::load(File.new(f))
            @records[f.to_i] = struct(data)
          end
        end
        @next_index = index.last.to_i + 1
      end

      def recordkeys ; @recordkeys ; end

      def struct(data)
        @structclass.new(*data.values_at(*recordkeys))
      end

      #def prime
      #  @klass.instance_variables
      #end

    end

  end

  Stores.register(:yaml, YamlStore)

end


