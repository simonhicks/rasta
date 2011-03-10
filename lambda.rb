class Lambda 
  def initialize(env, forms, params, *code)
    @env, @forms, @params, @code = env, forms, params, code
  end
  def call(*args)
    raise "Expected #{@params.size} arguments but got #{args}" unless args.size == @params.size
    newenv = Env.new(@env)
    newforms = Env.new(@forms)
    @params.zip(args).each do |sym, value|
      newenv.define(sym, value)
    end
    results = @code.map{|c| c.lispeval(newenv, newforms)}
    results[-1]
  end
  def to_proc
    proc{|*args| self.call(*args)}
  end
  def print_form
    Node.new(Label.new("do"), @params, *@code[0]).print_form # we access the 0th element because code is an array inside an array
  end
end
