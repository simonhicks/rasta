
(syntax-quote (abc def (unquote ghi)))
=> (list 'abc 'def ghi)

% node
  'abc
  'def
  (unquote ghi)

to syntax quote a node X
  if X.head == unquote
    emit X.contents[0]           ; X.contents should only have one thing in it anyway
  elsif X.head == unquote-splice
    emit X.contents[0]           ; and then insert the rest of X.contents after it
  else
    emit a Node, with 'node' as @head and the head & contents of the original node as contents
    syntax quote each item within the node (except for the @head (ie. 'node'))

to syntax quote anything else, emit (quote _)

% def apply-syntax-quote
  % do [a]
    % if (a :respond_to? :each)
      % if ((:head a) :!= unquote)
          % :each a apply-syntax-quote
          a
      % quote a

