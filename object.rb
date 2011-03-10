class Object
  def lispeval env, forms
    self
  end
  def const_get str
    self.class.const_get str
  end
  def call message, *args
    prc = args.pop if args[-1].kind_of?(Lambda)
    self.send message, *args, &prc
  end  
  def print_form
    to_s
  end
end

