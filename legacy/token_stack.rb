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

