require 'norma'
require './model.rb'
require './store.rb'

$norma_store.down
$norma_store.up

#MyClass.record_store(store)

# create and save
obj = MyClass.new(1,2,3)
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

