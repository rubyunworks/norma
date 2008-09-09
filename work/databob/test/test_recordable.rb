 
require 'databob/recordable'

class House
  attr_accessor :address, :city
end

class PhoneNumber
  attr_accessor :number, :location, :phone_type
end

class Member
  include Recordable

  attr_accessor :id, :member_id, :passcode, :name,
                :email, :active, :flags, :squimish,
                :tokens, :as_of, :modified

  #has_one House
  #has_many PhoneNumber
end

#dsn = 'dbi:Pg:database=meat_test;host=127.0.0.1;port=5432'
#Member.connection_set(dsn, 'meathead', 'love', 'AutoCommit' => false)

Member.establish_connection(
   :adapter  => "postgresql",
   :host     => "127.0.0.1",
   :username => "trans",
   :password => "pancakes",
   :database => "test"
)

#DatabaseConnection.establish_connection(
#     :adapter  => "postgresql",
#     :host     => "localhost",
#     :username => "meathead",
#     :password => "love",
#     :database => "meat_test"
#  )

Member.table = "members"
Member.primary_key = "id"

m = Member.new
m.id = 1
m.record_load
p m

#m.tokens = 33333
#m.update_database
#p m

#p m.methods

#if __FILE__ == $0
#
#  class Members
#    #class << self
#    #  def table; 'members'; end
#    #end
#    extend DBIze::SQLClassBuilder
#    build_sql_class()
#  end
#
#  m = Members.new
#  p m.methods.sort
#
#end
