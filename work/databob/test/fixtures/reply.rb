class Reply < Topic
  attr_accessible :title, :author_name, :author_email_address, :written_on, :content, :last_read

  def validate
    errors.add("title", "Empty")   unless attribute_present? "title"
    errors.add("content", "Empty") unless attribute_present? "content"
  end
  
  def validate_on_create
    errors.add("title", "is Wrong Create") if attribute_present?("title") && title == "Wrong Create"
    if attribute_present?("title") && attribute_present?("content") && content == "Mismatch"
      errors.add("title", "is Content Mismatch") 
    end
  end

  def validate_on_update
    errors.add("title", "is Wrong Update") if attribute_present?("title") && title == "Wrong Update"
  end
end