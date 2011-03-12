class Node
  def initialize head, *contents
    @head, @contents = head, contents
  end
  attr_accessor :head, :contents
  def lispeval(env, forms)
    return forms.lookup(@head).call(env, forms, *@contents) if forms.defined?(@head)
    func = head.lispeval(env, forms)
    return func.call(*(@contents.map{|x| x.lispeval(env,forms)}))
  end
  def print_form
    "% "+ @head.print_form + contents.map{|c| "\n#{c.print_form}".gsub("\n", "\n  ")}.join
  end
  def == other_node
    other_node.class == self.class && 
    other_node.head == self.head && 
    other_node.contents == self.contents
  end
end
