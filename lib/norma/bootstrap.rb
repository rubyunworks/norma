module Norma

  def self.bootstrap
    ObjectSpace.each_object(Class) do |c|
      c.store.bootstrap if c.store
    end
  end

end

