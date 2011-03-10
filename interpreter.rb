root_context = self
DEFAULTS = {
  "require" => proc{|*args| require(*args)},
  "ruby" => proc{|str| eval(str)},
  "true" => true,
  "false" => false,
  "self" => root_context,
  "nil" => nil
}

FORMS = {
  "quote" => lambda {|env, forms, exp| exp },
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
  "defmacro" => lambda{|env, forms, name, expr|
    func = exp.lispeval(env,forms)
    forms.define(name, lambda{|e2,f2,*rest| func.call(*rest).lispeval(env,forms)})
    name
  },
  "eval" => lambda{|env, forms, *code|
    code.map{|c| c.lispeval(env, forms)}.map{|c| c.lispeval(env, forms)}.last
  },
  "letmacro" => lambda{|env, forms, binding, body| 
    newforms = Env.new(forms) 
    binding.each_slice(2) {|name, f|
      func = f.lispeval(env, forms)
      newforms.define(name, lambda{|e2, f2, *rest| func.call(*rest).lispeval(env, forms)})
    }
    body.lispeval(env, newforms)
  },
  "." => lambda{|env, forms, object, message, *params| 
    evaled_params = params.map{|p| p.lispeval(env, forms)}
    prc = nil
    prc = evaled_params.pop if evaled_params.last.kind_of?(Lambda)
    object.lispeval(env, forms).send(message, *evaled_params, &prc)
  },
  "exit" => lambda{|env, forms| exit}
}

class Interpreter
  def initialize defaults=DEFAULTS, forms=FORMS
    @env = Env.new(nil, defaults)
    @forms = Env.new(nil, forms)
  end

  def eval(string)
    Lexer.tokenize(string).map do |exp|
      exp.lispeval(@env, @forms)
    end.last
  end

  def repl
    print "> "
    loop do
      text = ""
      until (line = gets.chomp).empty?
        print "> "
        text << line
      end
      begin
        puts "=> #{self.eval(text).print_form}"
      rescue StandardError => e
        puts "ERROR: #{e}"
      end
      print "> "
    end
  end
end


