
# Errors Classes

module DataBob

  class RecordError < Exception #:nodoc:
  end

  class RecordNotFound < RecordError #:nodoc:
  end

  class StatementInvalid < RecordError #:nodoc:
  end

end
