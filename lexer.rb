module Lexer
  REGEXP_RE = /\A\/(((\\\/)|[^\/])+)\/([xim]*)/
  TAB_WIDTH = 2

  def self.create_regex re, mods
    if mods.nil?
      modifier = nil
    else
      #mods = mods[2..-1].split("")
      mods = mods.split("")
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

  def self.get_line_num code, i
    code[0..i].scan(/\n/).count + 1
  end

  def self.tokenize(code)
    code.chomp!
    
    # Current character position we're parsing
    i = 0
    
    # Collection of all parsed tokens in the form [:TOKEN_TYPE, value]
    tokens = TokenStack.new
    
    # Current indent level is the number of spaces in the last indent.
    current_indent = 0
    
    while i < code.size
      chunk = code[i..-1]
      
      if numrange = chunk.match(/\A((\-?\d+)\.\.(\.)?(\-?\d+))/)
        tokens << Range.new(numrange[2].to_i, numrange[4].to_i, numrange[3])
        i += numrange[0].size

      elsif charrange = chunk.match(/\A("([a-zA-Z])"\.\.(\.)?"([a-zA-Z])")/)
        tokens << Range.new(charrange[2], charrange[4], charrange[3])
        i += charrange[0].size

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
        #mods = chunk[REGEXP_RE,2]
        #re = chunk[REGEXP_RE,3]
        mods = chunk[REGEXP_RE,4]
        re = chunk[REGEXP_RE,1].gsub("\\/", "/")
        tokens << create_regex(re, mods) 
        i += regex_match.size

      elsif string = chunk[/\A"(((\\")|[^"])+)"/m, 1]
        tokens << string.gsub('\"', '"')
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

      elsif identifier = chunk[/\A(&|($|:|\/|@|-|\w|\+|\?|!|=|\*|\||\.|<|>)+)/, 1] # anything alphnumeric, or with the symbols !, &, *, -, _, +, =, \, |, <, > is an indentifier (also ::)
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
