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

  def get_meta key = nil
    meta = self.instance_variable_get("@__meta")
    key ? meta && meta[key] : meta
  end

  def add_meta key, value
    meta = (get_meta || {}).dup
    meta[key] = value
    self.instance_variable_set "@__meta", meta
    self
  end
end

