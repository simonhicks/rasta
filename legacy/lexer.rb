require 'rational'

class NilClass
  def to_s
    "nil"
  end
end

class Symbol
  alias old_to_s to_s
  def to_s
    ":#{old_to_s}"
  end
  def __apply args
    args[0][self]
  end
end

class Array
  def __eval env, specials
    map{|e| e.__eval(env, specials)}
  end

  def __apply args
    self.[] args[0]
  end
end

class Hash
  def __eval env, specials
    Hash[*map{|e| e.__eval(env, specials)}.flatten]
  end

  def __apply args
    self.[] args[0]
  end
end

class Regexp
  def __apply args
    self.match(args[0])
  end
end

module Environment
  extend self
  def pr args
    print(*args.map(&:to_s).join(" "))
  end
  def prn args
    pr(*args)
    print("\n")
  end
  def + args
    args.inject(0){|m,e| m+e}
  end
  def - args
    args[1..-1].inject(args[0], &:-)
  end
  def * args
    args.inject(1, &:*)
  end
  def / args
    args[1..-1].inject(args[0], &:/)
  end
  def == args
    args[1..-1].inject(true){|m, e| e == args[0]}
  end
end

class Label
  def initialize content
    @content = content
  end
  attr_reader :content
  def to_s
    @content
  end
  def inspect
    to_s
  end
  def __eval env, specials
    case @content
    when /self/
      env
    when /([A-Z]\w*)./
      proc{|args| env.const_get($1).new(*args)}
    when /([A-Z]\w*)/
      env.const_get($1)
    when /(@\S+)=/
      proc{|args| env.instance_variable_set $1, args[0]}
    when /(@\S+)/
      env.instance_variable_get $1
    when /\.(\S+)/
      proc do |obj, *args| 
        if args.empty?
          obj.send($1)
        else
          obj.send($1, *args)
        end
      end
    else
      specials[@content] or env.method(@content)
    end
  end
end

class Object
  def __eval env, specials
    self
  end
  def __apply args
    if args == []
      self.send(:call)
    else
      self.send(:call, args)
    end
  end
end

class Node < Array
  def head
    self[0]
  end
  def contents
    Array.new self[1..-1]
  end
  def to_s
    "(#{map(&:to_s).join(" ")})"
  end
  def inspect
    to_s
  end
  def __eval env, specials
    __head = head.__eval(env, specials)
    if specials[head.content]
      __head.call(env, specials, contents)
    else
      args = contents.map{|e| e.__eval(env, specials)}
      __head.__apply(args)
    end
  end
end

class TokenStack
  TYPES = {
    [:OTHER, "%"] => [:DEDENT, Node],
    [:OTHER, "("] => [")", Node],
    [:OTHER, "["] => ["]", Array],
    [:OTHER, "{"] => ["}", Hash]
  }

  attr_reader :closer, :nested

  def initialize type = nil
    @exprs = []
    @nested = nil
    @closer, @type = TYPES[type]
  end

  def to_token
    if @type == Hash
      Hash[*@exprs]
    elsif @type
      @type.new @exprs
    else
      @exprs
    end
  end

  def handle_nested_token token
    if (token.is_a?(Array) && token[1] == @nested.closer) and !@nested.nested
      @exprs << @nested.to_token
      @nested = nil
    else
      @nested << token
    end
  end

  def opens_nesting? token
    TYPES.keys.include?(token)
  end

  def nest_token token
    @nested = TokenStack.new(token)
  end

  def << token
    if @nested 
      handle_nested_token token
    elsif opens_nesting?(token)
      nest_token token
    else
      @exprs << token
    end
    self
  end
end

class Lexer
  REGEXP_RE = /\A#"((\(\?[xim]+\))?(([^"]|\\")+?))"/
  TAB_WIDTH = 2

  def create_regex re, mods
    if mods.nil?
      modifier = nil
    else
      mods = mods[2..-1].split("")
      one,two,three = mods.map do |m|
        {"x" => Regexp::EXTENDED,
         "i" => Regexp::IGNORECASE,
         "m" => Regexp::MULTILINE}[m]
      end
      modifier = if three
                   one|two|three
                 elsif two
                   one|two
                 else
                   one
                 end
    end
    Regexp.new(re, modifier)
  end

  def get_line_num code, i
    code[0..i].scan(/\n/).count + 1
  end

  def tokenize(code)
    code.chomp!
    
    # Current character position we're parsing
    i = 0
    
    # Collection of all parsed tokens in the form [:TOKEN_TYPE, value]
    tokens = TokenStack.new
    
    # Current indent level is the number of spaces in the last indent.
    current_indent = 0
    
    while i < code.size
      chunk = code[i..-1]
      
      if ratio = chunk[/\A(-?[0-9]+\/[0-9]+)/, 1]
        numerator, denominator = ratio.split('/').map(&:to_i)
        tokens << Rational(numerator, denominator)
        i += ratio.size

      elsif float = chunk[/\A(-?[0-9]+\.[0-9]+)/, 1]
        tokens << float.to_f
        i += float.size

      elsif symbol = chunk[/\A:([^\]\[\{\}\(\)\s\n\r:][^\]\[\{\}\(\)\s\n\r]*)/, 1]
        tokens << symbol.to_sym
        i += symbol.size + 1
      
      elsif number = chunk[/\A(-?[0-9]+)/, 1]
        tokens << number.to_i
        i += number.size
        
      elsif regex_match = chunk[REGEXP_RE,0]
        mods = chunk[REGEXP_RE,2]
        re = chunk[REGEXP_RE,3]
        tokens << create_regex(re, mods) 
        i += regex_match.size

      elsif string = chunk[/\A"(([^"]|\")+?)"/m, 1]
        tokens << string
        i += string.size + 2

      elsif comment = chunk[/\A(;.*)/, 1]
        tokens << string
        i += comment.size

      elsif node = chunk[/\A\%/,0]
        # this creates a new syntax_node, so we need to increase the indent
        tokens << [:OTHER, "%"]
        i += 1
        current_indent += TAB_WIDTH

      elsif indent = chunk[/\A\n( +)[^ \t\r\f,;]/,1]
        if indent.size > current_indent # if the indent size is higher than expected, something has gone wrong."
          raise "Bad indent level in line #{get_line_num(code,i)}. Expected <= #{current_indent} spaces but got #{indent.size} spaces."
        elsif indent.size < current_indent # if the indent size has decresed, we need to close some nodes
          difference = current_indent - indent.size
          if (difference % TAB_WIDTH) == 0
            (difference/TAB_WIDTH).times { tokens << [:OTHER, :DEDENT]}
            current_indent = indent.size
          else
            raise "Bad indent level in line #{get_line_num(code,i)}. TAB_WIDTH is set to #{TAB_WIDTH}, but indent was #{indent.size}"
          end
        end
        i += (indent.size + 1)

      elsif close_all_indents = chunk[/\A\n[^ ,\n\t\r\f;]/] # any code on a line without any indentation means we close all indents
        (current_indent/TAB_WIDTH).times {tokens << [:OTHER, :DEDENT]}
        current_indent = 0
        i += 1

      elsif whitespace = chunk[/\A(\n|\r|\t|\f| |,)+/,1]
        i += whitespace.length

      elsif identifier = chunk[/\A((::)|(\/|@|-|\w|\+|\?|!|=|\*|&|\||\.|<|>)+)/, 1] # anything alphnumeric, or with the symbols !, &, *, -, _, +, =, \, |, <, > is an indentifier (also ::)
        tokens << Label.new(identifier) 
        i += identifier.size

      # We treat all other single characters as a token.
      else
        value = chunk[0,1]
        tokens << [:OTHER, value]
        i += 1
      end
      
    end
    
    (current_indent/TAB_WIDTH).times {tokens << [:OTHER, :DEDENT]}
    current_indent = 0
    
    tokens.to_token
  end
end

class Interpreter
  def initialize env = nil, specials = {}
    @lexer = Lexer.new
    @env = Environment
    @specials = specials
  end

  def evaluate code
    @lexer.tokenize(code).map{|expr| expr.__eval(@env, @specials)}.last
  end
end

SPECIALS = {
  "eval" => proc {|env, specials, args| args[0].__eval},
  "quote" => proc { |env, specials, args| args[0] },
  "self" => proc { |env, specials, args| env },
  "if" => proc do |env, specials, args|
            cond, then_node, else_node = args
            if cond.__eval(env, specials)
              then_node.__eval(env, specials)
            else
              else_node.__eval(env, specials)
            end
          end,
  "while" => proc do |env, specials, args|
               cond, *body = args
               while cond.__eval(env, specials)
                 body.each{|e| e.__eval(env, specials)}
               end
             end
}

@interpreter = Interpreter.new Environment, SPECIALS
print "> "
@input = gets
until @input == "exit"
  puts "=> #{@interpreter.evaluate(@input)}"
  print "> "
  @input = gets
end
