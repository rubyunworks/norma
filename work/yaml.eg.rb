

require 'rooms/rooms'

class MyClass

  attr_accessor :a, :b, :c

  def initialize( a,b,c )
    @a = a
    @b = b
    @c = c
  end

end

store = ROOMS::YamlStore.new( '/srv/rooms' )
MyClass.record_store( store )

#p store.count( MyClass )

obj2 = MyClass.record_load(2)

p obj2

# obj2 = MyClass.new( 4,5,6 )
# 
# p obj1
# p obj2
# 
# obj1.record_save
# obj2.record_save
# 
# p obj1.record_id
# p obj2.record_id
# 
# p obj1
# p obj2
# 
