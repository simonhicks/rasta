class Reader
  def initialize code
    @code = code
    @pos = 0
  end

  def << code
    @code << "\n" << code
  end

  REGEXP_RE = /\A\/(((\\\/)|[^\/])+)\/([xim]*)/
  TAB_WIDTH = 2

  def create_regex re, mods
    if mods.nil?
      modifier = nil
    else
      #mods = mods[2..-1].split("")
      mods = mods.split("")
      one,two,three = mods.map do |m|
        {"x" => Regexp::EXTENDED,
         "@pos" => Regexp::IGNORECASE,
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

  def get_line_num
    @code[0..@pos].scan(/\n/).count + 1
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
      elsif @type == Node
        Node.new *@exprs
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

  def tokenize
    # Collection of parsed tokens
    tokens = TokenStack.new
    
    # Current indent level is the number of spaces in the last indent.
    current_indent = 0
    
    while @pos < @code.size
      chunk = @code[@pos..-1]
      
      if numrange = chunk.match(/\A((\-?\d+)\.\.(\.)?(\-?\d+))/)
        tokens << Range.new(numrange[2].to_i, numrange[4].to_i, numrange[3])
        @pos += numrange[0].size

      elsif charrange = chunk.match(/\A("([a-zA-Z])"\.\.(\.)?"([a-zA-Z])")/)
        tokens << Range.new(charrange[2], charrange[4], charrange[3])
        @pos += charrange[0].size

      elsif float = chunk[/\A(-?[0-9]+\.[0-9]+)/, 1]
        tokens << float.to_f
        @pos += float.size

      elsif symbol = chunk[/\A:([^\]\[\{\}\(\)\s\n\r:][^\]\[\{\}\(\)\s\n\r]*)/, 1]
        tokens << symbol.to_sym
        @pos += symbol.size + 1
      
      elsif number = chunk[/\A(-?[0-9]+)/, 1]
        tokens << number.to_i
        @pos += number.size
        
      elsif regex_match = chunk[REGEXP_RE,0]
        mods = chunk[REGEXP_RE,4]
        re = chunk[REGEXP_RE,1].gsub("\\/", "/")
        tokens << create_regex(re, mods) 
        @pos += regex_match.size

      elsif string = chunk[/\A"(((\\")|[^"])+)"/m, 1]
        tokens << string.gsub('\"', '"')
        @pos += string.size + 2

      elsif comment = chunk[/\A(;.*)/, 1]
        tokens << string
        @pos += comment.size

      elsif node = chunk[/\A\%/,0]
        # this creates a new syntax_node, so we need to increase the indent
        tokens << [:OTHER, "%"]
        @pos += 1
        current_indent += TAB_WIDTH

      elsif indent = chunk[/\A\n( +)[^ \t\r\f,;]/,1]
        if indent.size > current_indent # if the indent size is higher than expected, something has gone wrong."
          raise "Bad indent level in line #{get_line_num}. Expected <= #{current_indent} spaces but got #{indent.size} spaces."
        elsif indent.size < current_indent # if the indent size has decresed, we need to close some nodes
          difference = current_indent - indent.size
          if (difference % TAB_WIDTH) == 0
            (difference/TAB_WIDTH).times { tokens << [:OTHER, :DEDENT]}
            current_indent = indent.size
          else
            raise "Bad indent level in line #{get_line_num}. TAB_WIDTH is set to #{TAB_WIDTH}, but indent was #{indent.size}"
          end
        end
        @pos += (indent.size + 1)

      elsif close_all_indents = chunk[/\A\n[^ ,\n\t\r\f;]/] # any @code on a line without any indentation means we close all indents
        (current_indent/TAB_WIDTH).times {tokens << [:OTHER, :DEDENT]}
        current_indent = 0
        @pos += 1

      elsif whitespace = chunk[/\A(\n|\r|\t|\f| |,)+/,1]
        @pos += whitespace.length

      elsif identifier = chunk[/\A(&|($|:|\/|@|-|\w|\+|\?|!|=|\*|\||\.|<|>)+)/, 1] # anything alphnumeric, or with the symbols !, &, *, -, _, +, =, \, |, <, > is an indentifier (also ::)
        tokens << Label.new(identifier) 
        @pos += identifier.size

      # We treat all other single characters as a token.
      else
        value = chunk[0,1]
        tokens << [:OTHER, value]
        @pos += 1
      end
    end
    
    (current_indent/TAB_WIDTH).times {tokens << [:OTHER, :DEDENT]}
    current_indent = 0
    
    tokens.to_token
  end
end
