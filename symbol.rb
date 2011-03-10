class Symbol
  def print_form
    ":#{to_s}"
  end
  def call *args
    if args.size == 1
      args[0].send self
    else
      obj = args.shift
      prc = args.pop if args[-1].kind_of?(Lambda)
      obj.send self, *args, &prc
    end
  end
end
