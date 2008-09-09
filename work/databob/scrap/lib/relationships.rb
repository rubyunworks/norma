#

module Recordable

  #
  module Relationships
  
    #
    def has_one(klass)
      kname = klass.name.downcase
      self.class_eval <<-EOS
        def #{kname}
          @#{kname}
        end
        def #{kname}=(k)
          @#{kname} = k
        end
      EOS
    end
    
    #
    def has_many(klass)
      kname = klass.name.downcase
      self.class_eval <<-EOS
        def #{kname}_collection
          @#{kname}_collection || []
        end
      EOS
    end
    
  end
  
end  # Recordable
