#class Lambda 
  #def initialize(env, forms, params, *code)
    #@env, @forms, @params, @code = env, forms, params, code
  #end
  
  #def call(*args)
    #raise "Expected #{@params.size} arguments but got #{args}" unless args.size == @params.size
    #newenv = Env.new(@env)
    #newforms = Env.new(@forms)
    #@params.zip(args).each do |sym, value|
      #newenv.define(sym, value)
    #end
    #results = @code.map{|c| c.lispeval(newenv, newforms)}
    #results[-1]
  #end

  #def to_proc
    #proc{|*args| self.call(*args)}
  #end

  #def print_form
    #Node.new(Label.new("do"), @params, *@code[0]).print_form # we access the 0th element because @code is an array inside an array
  #end
#end

@params = %w(a s d)
  def bindings params, args
    original = params.dup 
    rest = nil
    pairs = []
    until params.empty?
      p = params.shift
      if rest
        pairs << [p, args] # if we've had the "&" then we dump the rest into the final param
        break
      elsif p == "&"
        rest = true # otherwise, if this is the "&" then we ignore it for now and mark for the next iteration
      else
        pairs << [p, args.shift]
      end
    end
    raise "Invalid parameter declaration #{original}" if not params.empty?
    pairs
  end
b = bindings(@params, [1,2,3,4,5,6,7,8,9])
puts b.map{|k,v| [k.class, v]}

