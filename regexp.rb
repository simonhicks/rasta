class Regexp
  def print_mods
    mods = self.inspect.gsub(/\/.+\//, "")
    unless mods.empty?
      "(?#{mods})"
    end
  end
  def print_form
    self.inspect
  end
end
