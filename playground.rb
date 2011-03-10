class SyntaxQuotedTokenStack < TokenStack
  def initialize type = nil
    @exprs = []
    @nested = @reader_macro = nil
    @closer, @type = TYPES[type]
    @next_stack_class = SyntaxQuotedTokenStack
    @macros = {
      #[:OTHER, "'"] => proc{|expr| Node.new(Label.new("quote"), expr)},
      [:OTHER, "'"] => proc {|| @waiting_macros << proc{|expr| Node.new(Label.new("quote"), expr)}},
      [:OTHER, "~"] => proc {|| @waiting_macros << proc{|expr| expr}}
    }
  end

  def to_token
    if @type == Hash
      Hash[*@exprs]
    elsif @type == Node
      Node.new(:new, Label.new("Node"), *@exprs) # this should handle the 
    else
      @exprs
    end
  end

  def nest_token token
    @nested = @next_stack_class.new(token)
  end
  
  # add a token to the expression stack, applying the waiting reader macro if there is one
  def add_to_exprs token
    if @reader_macro
      @exprs << @reader_macro.call(token)
      @reader_macro = nil
    elsif [Node, Array, Hash].include?(token.class)
      @exprs << token # if it's one of these, then it's already come from a SyntaxQuotedTokenStack, so quoting is already taken care of
    else
      @exprs << Node.new(Label.new("quote"), token)
    end
  end
end

def l str
  Label.new(str)
end
def t str
  [:OTHER, str]
end
def convert *tokens
  stack = SyntaxQuotedTokenStack.new
  tokens.each{|t| stack << t}
  stack.to_token[-1]
end
