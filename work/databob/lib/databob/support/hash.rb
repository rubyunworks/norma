# Add a method to Ruby's built-in Hash class

class Hash
  # Converts all string keys in a hash to symbols.
  def symbolize_keys
    self.each { |k, v|
      if k.class != Symbol && k.respond_to?(:intern)
        self.delete k
        self[k.intern] = v
      end
    }
  end
end
