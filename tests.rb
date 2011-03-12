require File.join(File.expand_path(File.dirname(__FILE__)), "rasta").gsub(/.rb\Z/, "")

@tests = []
@fails = 0
@errors = []

def expect expected, string
  @tests << proc do
    begin
      actual = Interpreter.new.eval(string)
      unless actual == expected
        @fails += 1
        @errors << "\n\nFAIL:\n\n#{string}\nExpected: #{expected}\nActual:   #{actual}"
      end
    rescue Exception => e
      @fails += 1
      @errors << "\n\nFAIL:\n\n#{string}\nExpected:      #{expected}\nError Message: #{e}"
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
expect "12345", "% [1 2 3 4 5] :join"
expect Object, "((Object :new) :class)"

# basic arithmetic
expect 3, "(1 :+ 2)"
expect 2, "% 1 :* 2"
expect -1, "
% 1 
  :-
  2"
expect 0, "% 1 :/ 2"
expect 0.5, "% 1.0 :/ 2"
# nesting exprs
expect 5,
"
% % 3 :- 1
  :+
  % 6 :/ (1 :* 2)
"

# defining constants
expect 4,
"% def a 4
a"
expect 10, "
% def b 2
% def c 5
% b :* c
"

# letting variables
expect 10,"
% let
  [q 5]
  % q :+ q
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
  % [hello world] :join \" \"
"

# defining blocks
expect 4, "
% def double
  % do [x]
    % 2 :* x

% double 2"

# passing blocks to methods
expect "ABCDEF", "
% % (\"a\"..\"f\" :to_a) :map
    % do [letter] 
      % letter :upcase
  :join"

expect "ABCDEF", "
% % (\"a\"..\"f\" :to_a) :map
    % do [l] (l :upcase)
  :join"

# defining macros
expect :unchanged, "
% defmacro my-unless 
  [pred then else]
  % if (not pred) 
    then 
    else

% def macro-test :unchanged

% my-unless (1 :== 1)
  % set! macro-test :changed
  nil

macro-test"

# accessing self
expect self, "self"
# changing context via the "in" macro
expect Fixnum, "
% in 1
  % self :class"

# variable scope
expect "asdf", "
% def a 5

% let [a \"asdf\"] a
"
# env variables should still be available within an "in" block
expect 5, "
% def a 5

% in (Object :new) a"

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

# set!, if
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

# loading files
expect "Yes", '
% require "./test_require"

% RastaRequireTest :did_it_work?
'
expect "This worked too!", '
% require "test_require_again"
another-require-test
'

# comments
expect nil, '
nil
; this should be discarded'
expect 5, '
5
; this should be discarded
'

# meta-data
expect({:meta_data => "is awesome!"}, '
% def foo "Foo"
% add-meta! foo :meta_data "is awesome!"
% meta foo')
expect("This is a test", '
% def bar "Bar"
% add-meta! bar :test "This is a test"
% meta bar :test')
expect([:unchanged, :changed], '
% def spam "Spam"
% add-meta! spam :test :unchanged
% def eggs 
  % with-meta spam :test :changed
% [spam eggs] :map
  % do [a]
    % meta a :test')

# reader macros 
expect Label.new("foo"), "'foo"
expect Node.new(Label.new("puts"), 'hello', ' ', 'world'), '
% let [a "hello" b "world"]
  `% puts ~a " " ~b'
expect "hello world", '
% eval
  %let [a "hello" b " world"]
    `% def message 
      % ~a :+ ~b
message'
expect "hello world", '
% def str
  % do [s1 s2]
    % s1 :<< s2
% eval
  % let [a ["hello" " world"]]
    `% str ^a'

# defining methods
# without helpers
expect "hello", '
% Array :__define_instance_method :hello
  % do []
    "hello"
% def o []
% o :hello'
expect_error '
% Array :__define_instance_method :hello
  % do []
    "hello"
% Array :hello'
expect "goodbye", '
% Array :__define_class_method :goodbye
  % do [] "goodbye"
% Array :goodbye'

# executing ruby strings
expect "it worked", '% ruby "%w(it worked).join(\" \")"'

#variable arity blocks
expect %w(1 12 123 1234), '
% def foo
  % do [& letters]
    % letters :join 
[(foo 1) (foo 1 2) (foo 1 2 3) (foo 1 2 3 4)]'
expect_error '
% do [a & b c]
  % puts a'
expect_error '
% do [a b c &]
  % puts a'

# FIXME while

# FIXME for

if __FILE__==$0
  @tests.each(&:call)
  puts "#{@errors.join("\n")}\n\n#{(((@tests.size - @fails).to_f / @tests.size) * 100).to_i}% Passed. #{@fails} tests failed out of #{@tests.size} tests."
end

