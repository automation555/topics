% -*- latex -*-
\ignore{

\begin{code}
{-# LANGUAGE TypeOperators, GADTs #-}
module Input where
import SExpr
import Stack
\end{code}

}

\section{Adding input}
\label{sec:input}

While the study of the pure applicative language is interesting in its
own right (we come back to it in section~\ref{sec:zipper}), it is not enough
to represent parsers: it lacks dependency on the input.

We introduce an extra type argument (the type of symbols, |s|), as well as a new
constructor: |Symb|. It expresses that the rest of the expression depends on the
next symbol of the input (if any): its first argument is the parser to be used if the
end of input has been reached, while its second argument is used when there is
at least one symbol available, and it can depend on it.

\begin{code}
data Parser s a where
    Pure :: a                                  -> Parser s a
    (:*:) :: Parser s (b -> a) -> Parser s b   -> Parser s a
    Symb :: Parser s a -> (s -> Parser s a)    -> Parser s a
\end{code}

Using just this, as an example, we can write a simple parser for S-expressions.

\begin{code}
parseList :: Parser Char [SExpr]
parseList = Symb
   (Pure [])
   (\c -> case c of
       ')'  -> Pure []
       ' '  -> parseList -- ignore spaces
       '('  -> Pure (\h t -> S h : t) :*: parseList 
                   :*: parseList
       c    -> Pure ((Atom c) :) :*: parseList)
\end{code}


We adapt the |Polish| expressions with the construct corresponding to |Symb|, and amend
the translation. Intermediate results are represented by a Polish expression
with a |Susp| element. The part before the |Susp| element corresponds to the
constant part that is fixed by the input already parsed. The arguments of
|Susp| contain the continuations of the parsing algorithm: the first one 
if the end of input is reached, the second one when there is a symbol to consume.

\begin{code}
data Polish s r where
    Push     :: a -> Polish s r                  ->  Polish s (a :< r)
    App      :: Polish s ((b -> a) :< b :< r)    ->  Polish s (a :< r)
    Done     ::                                      Polish s Nil
    Susp     :: Polish s r -> (s -> Polish s r)  ->  Polish s r

toP :: Parser s a -> (Polish s r -> Polish s (a :< r))
toP (Symb nil cons) = 
       \k -> Susp (toP nil k) (\s -> toP (cons s) k)
toP (f :*: x)       = App . toP f . toP x
toP (Pure x)        = Push x
\end{code}

Although we broke the linearity of the type, it does no harm since the parsing
algorithm will not proceed further than the available input anyway, and
therefore will stop at the first |Susp|. Suspensions in a Polish expression can
be resolved by feeding input into it. When facing a suspension, we pattern match
on the input, and choose the corresponding branch in the result.

The |feed| function below performs this duty for a number of symbols, and stops
when it has no more symbols to feed. The dual function, |feedEof|, removes all
suspensions by consistently choosing the end-of-input alternative.

\begin{code}
feed :: [s] -> Polish s r -> Polish s r
feed  []      p                = p
feed  (s:ss)  (Susp nil cons)  = feed ss (cons s)
feed  ss      (Push x p)       = Push x  (feed ss p)  
feed  ss      (App p)          = App     (feed ss p)  
feed  ss      Done             = Done                 
\end{code} 


\begin{code}
feedEof :: Polish s r -> Polish s r
feedEof  (Susp nil cons)  = feedEof nil
feedEof  (Push x p)       = Push x  (feedEof p)  
feedEof  (App p)          = App     (feedEof p)  
feedEof  Done             = Done                 
\end{code} 

For example, |evalR $ feedEof $ feed "(a)" $ toPolish $ parseList| yields back our example expression: |S [Atom 'a']|.

We recall from section \ref{sec:mainloop} that feeding symbols one at a
time yields all intermediate parsing results.
\begin{spec}
allPartialParses = scanl (\p c -> feed [c] p)
\end{spec}
If the $(n+1)^{th}$ element of the input is changed, one can reuse
the $n^{th}$ element of the partial results list and feed it the
new input's tail (from that position).


This suffers from a major issue: partial results remain in their ``Polish
expression form'', and reusing offers little benefit, because no part of the
result value is shared between the partial results: the function |evalR| has to perform
the the full computation for each of them. 
Fortunately, it is possible to partially evaluate
prefixes of Polish expressions.

The following function performs this task
by traversing a Polish expression and applying functions along
the way.

\begin{code}
evalL :: Polish s a -> Polish s a
evalL (Push x r) = Push x (evalL r)
evalL (App f) = case evalL f of
                  (Push g (Push b r)) -> Push (g b) r
                  r -> App r
evalL x = x
partialParses = scanl (\p c -> evalL . feed [c] $ p)
\end{code}
This still suffers from a major drawback: as long as a function
application is not saturated, the Polish expression will start with
a long prefix of partial applications, which has to be traversed again
in forthcoming partial results.

For example, after applying the S-expression parser to the string \verb!abcdefg!, 
|evalL| is unable to perform any simplification of the list prefix:

\begin{spec}
evalL $ feed "abcdefg" (toPolish parseList) 
  ==  App $ Push (Atom 'a' :) $ 
      App $ Push (Atom 'b' :) $ 
      App $ Push (Atom 'c' :) $ 
      App $ ...
\end{spec}

This prefix will persist until the end of the input is reached. A
possible remedy is to avoid writing expressions that lead to this
sort of intermediate result, and we will see in section~\ref{sec:sublinear} how
to do this in the particularly important case of lists. This however works
only up to some point: indeed, there must always be an unsaturated
application (otherwise the result would be independent of the
input). In general, after parsing a prefix of size $n$, it is
reasonable to expect a partial application of at least depth
$O(log~n)$, otherwise the parser is discarding
information.

\subsection{Zipping into Polish}
\label{sec:zipper}

In this section we develop an efficient strategy to pre-compute intermediate results.
As seen in the above section, we want
to avoid the cost of traversing the structure up to the suspension at each step.
This suggests to use a zipper structure \citep{huet_zipper_1997} with the
focus at the suspension point.


\begin{code}
data Zip s out where
   Zip :: RPolish stack out -> Polish s stack -> Zip s out

data RPolish inp out where
  RPush  :: a -> RPolish (a :< r) out ->
               RPolish r out
  RApp   :: RPolish (b :< r) out ->
               RPolish ((a -> b) :< a :< r) out 
  RStop  ::    RPolish r r
\end{code}
Since the data is linear, this zipper is very similar to the zipper
for lists. The part that is already visited (``on the left''), is
reversed. Note that it contains only values and applications, since
we never go past a suspension.

The interesting features of this zipper are its type and its
meaning.
We note that, while we obtained the data type for the left part by
mechanically inverting the type for Polish expressions, it can be
assigned a meaning independently: it corresponds to \emph{reverse}
Polish expressions.

In contrast to forward Polish expressions, which directly produce
an output stack, reverse expressions can be understood as automata
which transform a stack to another. This is captured in the type
indices |inp| and |out|, which stand respectively for the input and the output stack.

Running this automaton requires some care:
matching on the input stack must be done lazily.
Otherwise, the evaluation procedure will force the spine of the input,
effectively forcing to parse the whole input file.
\begin{code}
evalRP :: RPolish inp out -> inp -> out
evalRP RStop acc          = acc 
evalRP (RPush v r) acc    = evalRP r (v :< acc)
evalRP (RApp r) ~(f :< ~(a :< acc)) 
                          = evalRP r (f a :< acc)
\end{code}

In our zipper type, the Polish expression yet-to-visit
(``on the right'') has to correspond to the reverse Polish
automation (``on the left''): the output of the latter has to match
the input of the former.

Capturing all these properties in the types (though GADTs)
allows to write a properly typed traversal of Polish expressions.
The |right| function moves the focus by one step to the right.
\begin{code}
right :: Zip s out -> Zip s out
right (Zip l (Push a r))  = Zip (RPush a l) r
right (Zip l (App r))     = Zip (RApp l) r   
right (Zip l s)           = Zip l s
\end{code}

As the input is traversed, in the implementation of |precompute|, we also simplify the prefix that we went past,
evaluating every application, effectively ensuring that each |RApp| is preceded
by at most one |RPush|.

\begin{code}
simplify :: RPolish s out -> RPolish s out
simplify (RPush a (RPush f (RApp r))) = 
             simplify (RPush (f a) r)
simplify x = x
\end{code}



We see that simplifying a complete reverse Polish expression requires $O(n)$
steps, where $n$ is the length of the expression. This means that the
\emph{amortized} complexity of parsing one token (i.e. computing a partial
result based on the previous partial result) is $O(1)$, if the size of the
result expression is proportional to the size of the input. We discuss the worst
case complexity in section~\ref{sec:sublinear}.

In summary, it is essential for our purposes to have two evaluation procedures
for our parsing results. The first one, presented in
section~\ref{sec:applicative}, provides the online property, and corresponds to
call-by-name CPS transformation of the direct evaluation of applicative
expressions. It underlies the |finish| function in our interface. The
second one, presented in this section, enables incremental evaluation of
intermediate results, and corresponds to a call-by-value transformation of the
same direct evaluation function. It underlies the |precompute| function.

\comment{
It is also interesting to note that, apparently, we could have done away
with the reverse Polish automaton entirely, and just have composed partial applications.
This solution, while a lot simpler, falls short of our purposes: such compositions of partially
applied functions are not simplified, given the standard evaluation models for Haskell. 
}

\comment{Interesting potential for the runtime system or compiler optimisation -- or is it?}