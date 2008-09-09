require 'abstract_unit'
# require File.dirname(__FILE__) + '/../dev-utils/eval_debugger'
require 'fixtures/company_in_module'

class ModulesTest < Test::Unit::TestCase
  def setup
    create_fixtures "accounts"
    create_fixtures "companies"
  end

  def test_module_spanning_associations
    assert MyApplication::Business::Firm.find_first.has_clients?, "Firm should have clients"
    firm = MyApplication::Business::Firm.find_first
    assert_nil firm.class.table_name.match('::'), "Firm shouldn't have the module appear in its table name"
    assert_equal 2, firm.clients_count, "Firm should have two clients"
  end
  
  def test_associations_spanning_cross_modules
    assert MyApplication::Billing::Account.find(1).has_firm?, "37signals account should be able to backtrack"
  end
end