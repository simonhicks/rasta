class Hash
  def lispeval(env, forms)
    Hash[*self.map{|k,v| [k.lispeval(env, forms), v.lispeval(env, forms)]}.flatten(1)]
  end

  def print_form
    "{#{map{|k,v| k.print_form+" "+v.print_form}.join(", ")}}"
  end
end
