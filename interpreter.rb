root_context = self
DEFAULTS = {
  "meta" => proc{|obj, key| obj.get_meta(key)},
  "add-meta!" => proc{|obj, key, value| obj.add_meta(key, value)},
  "with-meta" => proc{|obj, key, value| new_obj = obj.dup; new_obj.add_meta(key, value)},
  "ruby" => proc{|str| eval(str)},
  "not" => proc{|expr| not(expr)},
  "true" => true,
  "false" => false,
  "self" => root_context,
  "nil" => nil
}

FORMS = {
  "quote" => lambda {|env, forms, exp| exp },
  "splice" => lambda {|env, forms, exp| exp.lispeval(env, forms).add_meta(:spliced, true)},
  "def" => lambda {|env, forms, sym, value| env.define(sym, value.lispeval(env, forms)); sym},
  "set!" => lambda {|env, forms, sym, value| env.set(sym, value.lispeval(env, forms))},
  "if" => lambda {|env, forms, cond, xthen, xelse| 
    if cond.lispeval(env, forms)
      xthen.lispeval(env, forms)
    else
      xelse.lispeval(env, forms)
    end
  },
  "do" => lambda{|env, forms, params, *code| Lambda.new(env,forms, params, *code)},
  "let" => lambda{|env, forms, binding, *body|
    args, vals = binding.each_slice(2).to_a.transpose
    Lambda.new(env, forms, args, *body).call(*vals)
  },
  "in" => lambda{|env, forms, context, *body|
    newenv = Env.new(env, {"self"=> context})
    body.map{|e| e.lispeval(newenv, forms)}.last
  },
  "defmacro" => lambda{|env, forms, name, params, *code|
    func = Node.new(Label.new("do"), params, *code).lispeval(env,forms) # we construct a block (ie. a Lambda)
    forms.define(name, lambda{|e2,f2,*rest| func.call(*rest).lispeval(env,forms)}) # and the macro evals the result of calling that block
    name
  },
  "eval" => lambda{|env, forms, *code|
    code.map{|c| c.lispeval(env, forms)}.map{|c| c.lispeval(env, forms)}.last
  },
  "." => lambda{|env, forms, object, message, *params| 
    evaled_params = params.map{|p| p.lispeval(env, forms)}
    prc = nil
    prc = evaled_params.pop if evaled_params.last.kind_of?(Lambda)
    object.lispeval(env, forms).send(message, *evaled_params, &prc)
  },
  "stack-trace"=> lambda{|env, forms| puts $@},
  "exit" => lambda{|env, forms| exit}
}

class Interpreter
  def initialize defaults=DEFAULTS, forms=FORMS
    @env = Env.new(nil, defaults.merge({"require"=> proc{|*args| args.map{|a| self.load_rasta(a) || require(a)}.all?{|result| result}}}))
    @forms = Env.new(nil, forms)
    @rdr = Reader.new ""
  end

  def load_rasta name
    success = false
    [$:, File.dirname(__FILE__)].flatten.each do |path|
      file = "#{path}/#{name}.rst"
      if File.exist? file
        @rdr.prepend(open(file).read)
        success = true
        break
      end
    end
    success
  end

  def eval(string)
    @rdr << string
    result = nil
    while expr = @rdr.read
      result = expr.lispeval(@env, @forms)
    end
    result 
  end

  def repl
    print "> "
    loop do
      text = ""
      until (line = gets) =~ /\A\s+\Z/
        print "> "
        text << line
      end
      begin
        puts "=> #{self.eval(text).print_form}"
      rescue Exception => e
        raise e if e.is_a? SystemExit
        puts "ERROR: #{e}"
      end
      print "> "
    end
  end
end


