require File.join(File.expand_path(File.dirname(__FILE__)), "rasta").gsub(/.rb\Z/, "")

@tests = []
@fails = 0
@errors = []

def expect expected, string
  @tests << proc do
    actual = Interpreter.new.eval(string)
    unless actual == expected
      @fails += 1
      @errors << "\n\nFAIL:\n\n#{string}\nExpected: #{expected}\nActual:   #{actual}"
    end
  end
end

# literal forms
expect 1, "1"
expect 1.1, "1.1"
expect -1, "-1"
expect -12.8, "-12.8"
expect [1,2,3,4,5], '[1 2 3 4 5]'
expect({:a => 'a', :b => 'b'}, '{:a "a" :b "b"}')
expect /asdf/i, "/asdf/i"
expect Label.new("wierd-stuff/-!=+*?"), "(quote wierd-stuff/-!=+*?)"
expect Label.new("&"), "(quote &)"
expect [Label.new("&"), Label.new("again?")], "(quote [&again?])"
expect [:an, "array with", '"difficult"', /things\/literals/, Label.new("in-it")], %q([:an "array with" "\"difficult\"" /things\\\\/literals/ (quote in-it)])
expect :symbol, ":symbol"
expect Array, "Array"
module TestA ; class TestB; end; end
expect TestA::TestB, "TestA::TestB"
expect 0..10, "0..10"
expect 0...10, "0...10"

# message passing
expect "12345", "% :join [1 2 3 4 5]"
expect Object, "(:class (:new Object))"
expect Object, "(:class (:new Object))"

# basic arithmetic
expect 3, "(:+ 1 2)"
expect 2, "% :* 1 2"
expect -1, "
% :- 
  1 
  2"
expect 0, "% 1 :/ 2"
expect 0.5, "% 1.0 :/ 2"
# nesting exprs
expect 5,
"
% :+
  % 3 :- 1
  % 6 :/ (1 :* 2)
"

# defining constants
expect 4,
"% def a 4
a"
expect 10, "
% def b 2
% def c 5
% :* b c
"

# letting variables
expect 10,"
% let
  [q 5]
  % :+ q q
"
expect 6,"
% let
  [a 2 b 3]
  % a :* b
"
expect "hello world","
% let
  [hello \"hello\"
  ,world \"world\"]
  % :join [hello world] \" \"
"

# defining blocks
expect 4, "
% def double
  % do [x]
    % :* 2 x

% double 2
"
# passing blocks to methods
expect "ABCDEF", "
% :join
  % :map (\"a\"..\"f\" :to_a)
    % do [letter] 
      % letter :upcase
"
expect "ABCDEF", "
% :join
  % (\"a\"..\"f\" :to_a) :map
    % do [l] (l :upcase)
"

# defining macros
expect :unchanged, "
% defmacro my-unless 
  [pred then else]
  % if (not pred) 
    then 
    else

% def macro-test :unchanged

% my-unless (:== 1 1)
  % set! macro-test :changed
  nil

macro-test
"

# FIXME context
# FIXME scoping
# FIXME true/false/nil/self
# FIXME require, set!, if
# FIXME quote/eval
# FIXME . form
# FIXME letmacro
# FIXME executing ruby strings

if __FILE__==$0
  @tests.each(&:call)
  puts "#{(((@tests.size - @fails).to_f / @tests.size) * 100).to_i}% Passed. #{@fails} tests failed out of #{@tests.size} tests.#{@errors.join("\n")}"
end

