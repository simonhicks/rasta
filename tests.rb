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
def expect_error string
  @tests << proc do
    begin
      actual = Interpreter.new.eval(string)
      @fails += 1
      @errors << "\n\nFail: \n\n#{string}\nAn error was expected, but none was thrown.\nResult: #{actual}"
    rescue
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

# accessing self
expect self, "self"
# changing context via the "in" macro
expect Fixnum, "
% in 1
  % :class self
"

# variable scope
expect "asdf", "
% def a 5

% let [a \"asdf\"] a
"
# env variables should still be available within an "in" block
expect 5, "
% def a 5

% in (:new Object) a
"

# quote/eval
expect Label.new("bar"), "(quote bar)"
expect_error "foo"

# true/false/nil
expect true, "true"
expect false, "false"
expect nil, "nil"

# . form
expect "12345", "% . [1 2 3 4 5] join"
expect "12345", "% . [1 2 3 4 5] :join"

# require, set!, if
expect "Yes", '
% require "./test_require"

% RastaRequireTest :did_it_work?
'
expect 2, "
% def a 1
% set! a (1 :+ a)
a
"
expect :unchanged, "
% def a :unchanged
% if true
  nil
  % set! a :changed
a
"
expect :changed, "
% def a :unchanged
% if false
  nil
  % set! a :changed
a
"

# FIXME loading rasta files

# comments
expect nil, '
nil
; this should be discarded
'

# FIXME add more of these...
# reader macros 
expect Label.new("foo"), "'foo"

# executing ruby strings
expect "it worked", '% ruby "%w(it worked).join(\" \")"'

if __FILE__==$0
  @tests.each(&:call)
  puts "#{(((@tests.size - @fails).to_f / @tests.size) * 100).to_i}% Passed. #{@fails} tests failed out of #{@tests.size} tests.#{@errors.join("\n")}"
end

