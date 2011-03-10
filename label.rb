class Label < String
  def fetch_as_constant env
    context = env.lookup("self")
    case self
    when /\A::/
      self.gsub(/\A::/, '').fetch_as_constant Kernel
    when /::/
      self.split(/::/).inject(context) do |m, e|
        m.const_get(e)
      end
    else
      context.const_get(self)
    end
  end
  def lispeval env, forms
    if self[/\A(::)|[A-Z]/]
      fetch_as_constant env
    elsif self[/\A(@.+)=/]
      proc{|value| env.lookup("self").instance_variable_set($1, value)}
    elsif self[/\A@.+/]
      env.lookup("self").instance_variable_get(self)
    else
      normal_lookup = env.lookup(self)  # this is so we can lookup "nil" in env and receive nil
      if (normal_lookup == false and self != "false")
        return forms.lookup(self) || env.lookup("self").method(self) # if the symbol isn't found we call it as a method on the context
      else
        return normal_lookup
      end
    end
  end
  def print_form
    self
  end
end
