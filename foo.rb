require './rasta'
str = '
% require "test_require_again"

another-require-test 
'
puts Interpreter.new.eval(str)
