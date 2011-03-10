module Enumerable
  def lispeval(env, forms)
    map{|e| e.lispeval(env, forms)}
  end
end
