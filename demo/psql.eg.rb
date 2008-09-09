
require 'norma/orm'


class MyClass

  attr_accessor :a, :b, :c, :d

  def initialize( a,b,c )
    @a = a
    @b = b
    @c = c
    @d = [ a, b, c ]
  end

end

store = Norma::Database::Psql.connect(
  :database => 'norma_development',
  :username => 'trans',
  :password => 'trans'
)

$norma_store = store

#store.down
#store.up
#exit 0

#MyClass.record_store( store )

#p store.count( MyClass )

obj = MyClass.new( 1,2,3 )
obj.as_record.save

#obj2 = MyClass.record_load( obj.record_id )
#p obj2

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
