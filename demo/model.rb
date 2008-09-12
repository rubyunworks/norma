class MyClass

  attr_accessor :a, :b, :c, :d

  def initialize( a,b,c )
    @a = a
    @b = b
    @c = c
    @d = [ a, b, c ]
  end

end

