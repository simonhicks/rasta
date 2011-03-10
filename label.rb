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
      env.lookup(self) || forms.lookup(self) || env.lookup("self").method(self) # if the symbol isn't found we call it as a method on the context
    end
  end
  def print_form
    self
  end
end
