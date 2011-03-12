class Lambda 
  def initialize(env, forms, params, *code)
    raise "Invalid parameter declaration #{params}" if invalid_params?(params)
    @env, @forms, @params, @code = env, forms, params, code
  end

  def invalid_params? params
    (splat = params.find_index("&")) && splat != params.length - 2
  end

  def call(*args)
    newenv = Env.new(@env)
    newforms = Env.new(@forms)
    b = bindings(@params, args)
    b.each do |sym, value|
      newenv.define(sym, value)
    end
    results = @code.map{|c| c.lispeval(newenv, newforms)}
    results[-1]
  end

  def to_proc
    proc{|*args| self.call(*args)}
  end

  def print_form
    Node.new(Label.new("do"), @params, *@code[0]).print_form # we access the 0th element because @code is an array inside an array
  end

  def bindings params, args
    params2 = params.dup 
    args2 = args.dup
    rest = nil
    pairs = []
    until params2.empty?
      p = params2.shift
      if rest
        pairs << [p, args2] # if we've had the "&" then we dump the rest into the final param
      elsif p == "&"
        rest = true # otherwise, if this is the "&" then we ignore it for now and mark for the next iteration
      else
        pairs << [p, args2.shift]
      end
    end
    pairs
  end
end
