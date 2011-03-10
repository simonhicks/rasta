class Array
  def lispeval(env, forms)
    map{|e| e.lispeval(env, forms)}
  end

  def print_form
    "[" + self.map{|e| e.print_form}.join(" ") + "]"
  end
end
