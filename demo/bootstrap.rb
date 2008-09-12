require 'norma'
require './model.rb'
require './store.rb'

$norma_store.bootstrap

p MyClass.records

#p store.count( MyClass )

#Norma.bootstrap

#MyClass.record_store( store )

#p store.count( MyClass )

#obj = MyClass.new(1,2,3)
#obj.as_record.save

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

