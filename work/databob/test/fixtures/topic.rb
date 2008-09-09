class Topic < ActiveRecord::Base
  before_create  :default_written_on
  before_destroy :destroy_children #'self.class.delete_all "parent_id = #{id}"'

  def parent
    self.class.find(parent_id)
  end
  
  protected
    def default_written_on
      self.written_on = Time.now unless attribute_present?("written_on")
    end

    def destroy_children
      self.class.delete_all "parent_id = #{id}"
    end
end