sys = require('sys')
Array::__eval = (env, specials) ->
  for e in this
    e.__eval(env, specials) if e?
Array::__apply = (args...) ->
    this[args[0]]
Array::toString = () ->
  "[" + this.join(" ") + "]"
Array::blah = (arg) ->
  "BLAH #{arg}"

Object::__eval = (env, specials) ->
  this
Object::__apply = (args...) ->
  this[args[0]]

Function::__apply = (args) ->
  this(args...)
Function::__eval = (env, specials) ->
  this

class HashMap extends Object
  constructor: (pairs...) ->
    for i in [0..pairs.length] by 2
      do (i) ->
        key = pairs[i]
        this[key] = pairs[i+1]
  __eval: (env, specials) ->
    result = {}
    for key,value in this
      result[key] = value.__eval(env,specials) if value?
    result

class Environment
  constructor: (bindings)->
    bindings ?= {}
    for name, func in bindings
      @[name] = func

  reduce: (fn, init, coll) ->
    result = init
    for elem in coll
      result = fn(result, elem)
    result

  "+": (args...) ->
    result = 0
    for elem in args
      result += elem
    result
  "-": (args...) ->
    result = args[0]
    for elem in args[1..args.length]
      result -= elem
    result
  "*": (args...) ->
    result = 1
    for elem in args
      result = elem * result
    result
  "/": (args...) ->
    result = args[0]
    for elem in args[1..args.length]
      result = result/elem
    result
  pr: (args...)->
    sys.puts(x + " ") for x in args

class Label
  constructor: (@content) ->
  toString: ->
    @content
  __eval: (env, specials) ->
    if (result = @content.match(/@(\S+)=/))
      (arg) ->
        env[result[1]] = arg
    else if (result = @content.match(/@(\S+)/))
      env[result[1]]
    else if (result = @content.match(/\.(\S+)/))
      (obj, args...) ->
        obj[result[1]](args...)
    else
      (specials and specials[@content]) or env[@content]

class SyntaxTree
  constructor: () ->
    @elements =[]
  push: (e) ->
    @elements.push(e)
  head: () -> @elements[0]
  contents: () -> @elements[1..this.length]
  toString: () ->
    "("+@elements.join(" ")+")"
  __eval: (env, specials) ->
    args = if specials[@head()]?
      [@env, @specials, @contents()...]
    else
      for e in @contents()
        e.__eval(env,specials) if e?
    __head = @head().__eval(env, specials)
    __head.__apply(args)


class SyntaxToken
  constructor: (@type) ->
  toString: () ->
    @type

class TokenStack
  TYPES:
    "%": ["DEDENT", "SyntaxTree"],
    "(": [")", "SyntaxTree"],
    "[": ["]", "Array"],
    "{": ["}", "HashMap"]
  constructor: (token_type) ->
    [@closer, @node_type] = @TYPES[token_type] or [null, null]
    @nested = null
    @exprs = []
  tree: () ->
    if @node_type == "HashMap"
      new HashMap(@exprs...)
    else if @node_type == "SyntaxTree"
      result = new SyntaxTree()
      result.push(e) for e in @exprs
      result
    else
      @exprs
  handle_nested_token: (token) ->
    if token.type == @nested.closer and !@nested.nested # this token closes the current nested TokenStack 
      @exprs.push(@nested.tree())
      @nested = null
    else
      @nested.push(token)
  opens_nesting: (token) ->
    token.type && (@TYPES[token.type]?)
  nest_token: (token) ->
    @nested = new TokenStack(token.type)
  push: (token) ->
    if @nested?
      @handle_nested_token(token)
    else if @opens_nesting(token)
      @nest_token(token)
    else
      @exprs.push(token)

class Lexer
  REGEXP_RE: /^\/(([^\/]|\\\/)+)\/([gim]*)/
  TAB_WIDTH: 2

  get_line_num: (code, i) ->
    code[0..i].split(/\n/).length

  tokenize: (code) ->
    i = 0 # Current character position we're parsing
    @tokens = new TokenStack() # Collection of all parsed tokens
    current_indent = 0 # Current indent level is the number of spaces in the last indent.
    
    while i < code.length
      chunk = code.substring(i)
      
      if float = chunk.match(/^(-?[0-9]+\.[0-9]+)/)
        @tokens.push(parseFloat(float[1]))
        i += float[0].length

      else if number = chunk.match(/^(-?[0-9]+)/)
        @tokens.push(parseInt(number[1]))
        i += number[0].length
        
      else if regex_match = chunk.match(@REGEXP_RE)
        mods = chunk.match(@REGEXP_RE)[3]
        re = chunk.match(@REGEXP_RE)[1]
        @tokens.push(new RegExp(re, mods))
        i += regex_match[0].length

      else if string = chunk.match(/^"(([^"]|\")+?)"/m)
        @tokens.push(string[1])
        i += string[0].length

      else if comment = chunk.match(/^(;.*)/)
        i += comment[0].length

      else if node = chunk.match(/^\%/) # this creates a new syntax_node, so we need to increase the indent
        @tokens.push(new SyntaxToken("%"))
        i += 1
        current_indent += @TAB_WIDTH

      else if indent = chunk.match(/^\n( +)[^ \t\r\f;]/) 
        indent = indent[1]
        if indent.length > current_indent # if the indent length is higher than expected, something has gone wrong."
          throw(new Error("Bad indent level in line #{get_line_num(code,i)}. Expected <= #{current_indent} spaces but got #{indent.length} spaces."))
        else if indent.length < current_indent # if the indent length has decresed, we need to close some nodes
          difference = current_indent - indent.length
          if (difference % @TAB_WIDTH) == 0
            num = (difference/@TAB_WIDTH)
            for n in [1..num] 
              @tokens.push(new SyntaxToken("DEDENT"))
            current_indent = indent.length
          else
            throw(new Error("Bad indent level in line #{get_line_num(code,i)}. @TAB_WIDTH is set to #{@TAB_WIDTH}, but indent was #{indent.length}"))
        i += (indent.length + 1)

      else if close_all_indents = chunk.match(/^\n[^ ,\n\t\r\f;]/) # any code on a line without any indentation means we close all indents
        num = (current_indent/@TAB_WIDTH)
        for n in [1..num] 
          @tokens.push(new SyntaxToken("DEDENT"))
        current_indent = 0
        i += 1

      else if whitespace = chunk.match(/^(\n|\r|\t|\f| |,)/)
        i += 1

      else if identifier = chunk.match(/^((::)|(\/|@|-|\w|\+|\?|!|=|\*|&|\||\.|<|>)+)/) # anything alphnumeric, or with the symbols !, &, *, -, _, +, =, \, |, <, > is an indentifier (also ::)
        @tokens.push(new Label(identifier[1]))
        i += identifier[0].length

      # We treat all other single characters as a token.
      else
        value = chunk.substring(0,1)
        @tokens.push(new SyntaxToken(value))
        i += 1
      
    num = (current_indent/@TAB_WIDTH)
    for n in [1..num] 
      @tokens.push(new SyntaxToken("DEDENT"))
    current_indent = 0
    
    @tokens.tree()

class Interpreter
  constructor: (@env, @specials) ->
    @env ?= new Environment()
    @specials ?= {
      ".": (env, specials, obj, method, args...)->
        args = arg.__eval(env, specials) for arg in args
        obj.__eval(env, specials)[method](args...)
    }
    @lexer = new Lexer

  evaluate: (code) ->
    exprs = @lexer.tokenize(code.toString())
    results = for expr in exprs
      expr.__eval(@env, @specials)
    results.pop()

#new Interpreter()

#fs = require('fs')
#fs.readFile 'test.rasta', (e,cont) -> 
  #(new Interpreter()).evaluate(cont)
  ##sys.puts((new Lexer()).tokenize(cont.toString()))
  
env = new Environment()
sys.puts(env['+'])
#sys.puts([1,2,3].__eval(env, {}))

#m =  env['+']
#m(1,2,3)
