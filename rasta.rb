%w(regexp string symbol array hash label nil_class object node env lambda reader token_stack lexer interpreter).each do |f|
  require File.join(File.expand_path(File.dirname(__FILE__)), f)
end

if __FILE__ == $0
  if ARGV[0]
    code = open(File.expand_path(ARGV[0])).read
    Interpreter.new.eval code
  else
    Interpreter.new.repl
  end
end
