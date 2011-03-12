class Class
  def __define_instance_method name, &block
   self.send(:define_method, name) do |*a|
     block.call(*a)
   end
  end

  def __define_class_method name, &block
    self.singleton_class.send(:define_method, name) do |*a|
      block.call(*a)
    end
  end
end
