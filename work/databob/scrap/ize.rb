#
=begin

=end

require 'tomslib/rubylib'

module Jigsaw

  module Ize

     #
    ###
     #

    class View

      attr_accessor :parent

      def initialize(parent=nil)
        @parent = parent
      end

      def load_from_hash(h)
        h.to_h.each do |name, value|
          case value
          when Hash
            if (pr = self.respond_with_value(name.intern)).kind_of?(Jigsaw::Ize::Record)
              pr.load_hash(value)
            else
              self.send("#{name}=".intern, value) if self.respond_to?("#{name}=".intern)
            end
          when Array
            if value.select { |s| !s.kind_of?(Hash) }.empty? and (sr = self.respond_with_value(name.intern)).kind_of?(Jigsaw::Ize::Recordset)
              sr.load_array(value)
            else
              self.send("#{name}=".intern, value) if self.respond_to?("#{name}=".intern)
            end
          else
            self.send("#{name}=".intern, value) if self.respond_to?("#{name}=".intern)
          end
        end
      end
      
      #
            
      def related_records
        self.instance_variables.collect { |ivar| instance_eval("#{ivar}") }.find_all { |iobj| iobj.kind_of?(Jigsaw::Ize::Record) }
      end

      def related_recordsets
        t = []
        self.instance_variables.each do |ivar|
          iobj = instance_eval("#{ivar}")
          t << iobj if iobj.kind_of?(Jigsaw::Ize::Recordset)
        end
        return t
      end

      # views and viewsets include records and recordsets

      def related_views
        self.instance_variables.collect { |ivar| instance_eval("#{ivar}") }.find_all { |iobj| iobj.kind_of?(Jigsaw::Ize::View) }
      end

      def related_viewsets
        t = []
        self.instance_variables.each do |ivar|
          iobj = instance_eval("#{ivar}")
          t << iobj if iobj.kind_of?(Jigsaw::Ize::Viewset)
        end
        return t
      end
      
    end
    
     #
    ###
     #

    class Viewset < Array

      attr_accessor :set_class
      attr_accessor :parent

      def initialize(set_class, parent=nil)
        @set_class = set_class
        @parent = parent
        super()
      end

      def load_from_array(a, *args)
        a.each do |r|
          self << self.set_class.new(*args)
          self.last.load_from_hash(r.to_h)
        end
      end

      # modified array methods

      def insert_at(i=nil, *args)
        if i and i.abs < self.length
          self[i, 0] = [ self.set_class.new(*args) ]
          self[i].parent = self
        else
          i = self.length
          self << self.set_class.new(*args)
          self.last.parent = self
        end
      end

      def <<(x)
        if not x.kind_of?(self.set_class)
          raise 'attempting to append subrecord of incorrect type'
        else
          x.parent = self
          super
        end
      end

      # these need to be disabled for now to prevent errors

      def collect!() end
      def concat() end
      def fill() end
      def map!() end
      def push() end
      def replace() end

    end
    
     #
    ###
     #

    class Record < View

      attr_accessor :parent

      def initialize(parent=nil)
        super
        if self.parent.kind_of?(View)
          if sr = self.references
            if sr.kind_of?(Symbol)
              self.class.class_eval <<-EOS
                def #{self.primary_key}()
                  self.parent.#{self.references}()
                end
              EOS
            else
              references.each do |k,v|
                self.class.class_eval <<-EOS
                  def #{k}()
                    self.parent.#{v}()
                  end
                EOS
              end
            end
          end
        elsif parent.kind_of?(Ize::Viewset)
          if self.parent.parent
            if sr = self.references
              if sr.kind_of?(Symbol)
                self.class_eval <<-EOS
                  def #{self.primary_key}()
                    self.parent.parent.#{self.references}()
                  end
                EOS
              else
                references.each do |k,v|
                  self.class_eval <<-EOS
                    def #{k}()
                      self.parent.parent.#{v}()
                    end
                  EOS
                end
              end
            end
          end
        end
      end

    end

     #
    ###
     #

    class Recordset < Viewset

    end

  end

end
