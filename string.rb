class String
  def print_form
    "\"#{self.gsub('"', '\"')}\""
  end
end
