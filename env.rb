class Env 
  FORBIDDEN = %w(self true false nil)

  def initialize(parent=nil, defaults={})
    @parent = parent
    @defs = defaults
  end

  def define(symbol, value)
    raise "You can't change #{symbol}" if FORBIDDEN.include? symbol
    @defs[symbol] = value
    return value
  end

  def defined?(symbol)
    return true if @defs.has_key?(symbol) 
    return false if @parent.nil? 
    return @parent.defined?(symbol)
  end

  def lookup(symbol)
    return @defs[symbol] if @defs.has_key?(symbol) 
    if @parent.nil?
      return false
    end
    return @parent.lookup(symbol)
  end

  def set(symbol, value)
    raise "ERROR: You can't change #{symbol}" if FORBIDDEN.include? symbol
    if @defs.has_key?(symbol)
      @defs[symbol] = value
    elsif @parent.nil? 
      raise "No definition of #{symbol} to set to #{value}"
    else 
      @parent.set(symbol, value)
    end
  end
end
