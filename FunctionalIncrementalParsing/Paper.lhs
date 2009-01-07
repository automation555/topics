% -*- latex -*-
\documentclass[preprint]{sigplanconf}
%include lhs2TeX.fmt
%format :*: = " \applbind"
%format +> = " \secondPush"
\usepackage{amsmath}
\usepackage[mathletters]{ucs}
\usepackage[utf8x]{inputenc}
\usepackage{graphicx}
\usepackage{pgf}
\usepackage{tikz}
\setlength{\parindent}{0pt}
\setlength{\parskip}{3pt}
\usepackage{enumerate}
% \usepackage[sort&compress,numbers]{natbib}
\usepackage[sort&compress]{natbib}
\newcommand{\ignore}[1]{}
\providecommand{\TODO}[1]{\footnote{#1}}
\providecommand{\annot}[1]{\marginpar{\footnotesize \raggedright #1}}
\newcommand{\applbind}{\mathbin{:\!\!*\!\!:}}
\newcommand{\secondPush}{\mathbin{+\!\!>}}
\newcommand{\prog}{\ensuremath{\mathbin{:>}}}

\newenvironment{meta}{%
\begin{quote}
\sf
}{%
\end{quote}
}

\providecommand{\textmeta}[1]{\begin{quote}\textsf{{#1}}\end{quote}}

\begin{document}

\titlebanner{Work in progress}        % These are ignored unless
\preprintfooter{In preparation for ICFP09}   % 'preprint' option specified.

\title{Lazy Functional Incremental Parsing}

\authorinfo{Jean-Philippe Bernardy}
           {Computer Science and Engineering, 
            Chalmers University of Technology and University of Gothenburg}
           {bernardy@@chalmers.se}


\maketitle
\begin{abstract}
A free-form editor for structured documents may want to maintain
a structured representation of the edited document. This has
a number of applications: structural navigation (and optional strucural edition), 
highlighting of source code, etc. 
We show that combining
lazy evaluation and caching of intermediate (partial) results
enables to parse the input incrementally. We also introduce a general purpose,
simple data structure, to eliminate the linear complexity caused
by lazy lists traversals while retaining their lazy properties.
Finally, we complete our exposition of incremental parsing in an
interactive system by showing how our parsing machinery can be
improved to support error-correction.
\end{abstract}

\category{D.3.4}{Programming Languages}{Processors}
\category{D.2.3}{Coding Tools and Techniques}{Program editors}
\category{D.1.1}{Programming Techniques}{Applicative (Functional) Programming}
\category{F.3.2}{Logics and Meanings of Programs}{Semantics of Programming Languages}

\terms
Algorithms, Languages, Design, Performance, Theory

\keywords
Functional Programming, Lazy evaluation, Incremental Computing, Parsing,
Dynamic Programming, Polish representation, Editor, Haskell


\section{Introduction}

Yi \citep{bernardy_yi:editor_2008,stewart_dynamic_2005} is a text editor written
in Haskell. It provides features such as syntax highlighting and indentation
hints for a number of programming languages. In order to implement all syntax-dependent
functions in a consistent way, the abstract syntax tree (AST) of the source code is available at
all times, kept up to date as the user types. In order to maintain acceptable
performance, the editor must not parse the whole file at each keystroke.

\subsection{Example}

For the purpose of illustration, we demonstrate how the
technique works on a simple problem: interactive feedback of
parenthesis matching for a lisp-like language. Given an input such
as \verb!(+ 1 (* 5 (+ 3 4)) 2)!, the program will display an annotated version:
\verb!(+ 1 {* 5 [+ 3 4]} 2)!. The idea is that matching pairs are
displayed using different parenthetical symbols for each level,
making the extent of each sub-expression more apparent.

The production of the output is a two-phase process. First, the AST
is produced, by parsing the input. A value of the |SExpr| type
is constructed. Second, it is linearized back and
printed to the user.

%include SExpr.lhs

\begin{figure}
\includegraphics[width=\columnwidth]{begin}
\caption{Viewing the beginning of a file. 
The big triangle represents the syntax tree. The line at the bottom represents the
file. The zagged part indicates the part that is parsed. The viewing window is
depicted as a rectangle.
}
\label{fig:begin}
\end{figure}

The initial situation is depicted in figure~\ref{fig:begin}. The user views the
beginning of the file. To display the decorated output, the program
has to traverse the first few nodes of the syntax tree (in
pre-order). This in turn forces parsing the corresponding part of
the output, but \emph{only so far} (or maybe a few tokens ahead,
depending on the amount of lookahead required). If the user modifies
the input at this point, it invalidates the AST, but discarding it and
re-parsing is not too costly: only a screenful of parsing needs to be
re-done.

\begin{figure}
\includegraphics[width=\columnwidth]{mid}
\caption{
Viewing the middle of a file. 
Although only a small amount of the
parse tree may be demanded, parsing must start from the beginning of the
file.}
\label{fig:mid}
\end{figure}

As the user scrolls down in the file, more and more of the AST is demanded, and
the parsing proceeds in lockstep (figure~\ref{fig:mid}). At this stage, a user
modification is more serious: re-parsing naively from the beginning can be too
costly for a big file. Fortunately we can again exploit the linear behaviour of
parsing algorithms to our advantage. Indeed, if we have stored the parser state
for the input point where the user made the modification, we can \emph{resume}
parsing from that point. If we make sure to store partial results for every
other point of the input, we can ensure that we will never parse more than a
screenful at a time.

Another feature of Yi is that it is configurable in Haskell. Therefore, we
prefer to use the Haskell language for every aspect of the application. In
particular, syntaxes should be described using a combinator library.

The main characteristics of our solution can be summarized as follows:
\begin{itemize}
\item it is a parser combinator library;
\item it makes maximal usage of laziness;
\item it must be performant enough of interactive usage.
\end{itemize}

This has a number of consequences:
\begin{itemize}

\item We will not attempt to update the previous parsing results;

\item Returning the result lazily requires our parsing function to be total,
hence we will have to provide error correction.

\end{itemize}


\subsection{Contributions}

Our contributions can be summarized as follows.

\begin{itemize}
\item
  We describe a novel, purely functional approach to incremental parsing, which
  makes essential use of lazy evaluation. This is achieved by
  combinining online parsers with caching of intermediate
  results.

\item
  We complete our treatment of incremental parsing with 
  error correction. This is essential, since online parsers
  need to be \emph{total}: they cannot fail on any input;

\item
  We craft a data structure to be used in place of lists, which is
  more efficient but has the same properties for laziness;

\item
  We have implemented such a system in a parser-combinator library;

\item
  We have implemented such a system and made use of it to provide
  syntax-dependent feedback in a production-quality editor.

\end{itemize}

\subsection{Summary and outlook}

In an interactive system, a lazy evaluation strategy provides a
special form of incremental computation: the amount of output that
is demanded drives the computation to be performed. In other words,
the system responds to incremental movements of the portion of the
output being viewed by the user (window) by incremental computation
of the intermediate structures.

The above observation suggests that we can take advantage of lazy evaluation to
implement incremental parsing for a text editor.
Indeed, if we suppose that the user makes changes in the input that
``corresponds to'' the window being viewed, it suffices to cache
partially computed results for each point in the input, to obtain a
system that responds to changes in the input independently of the
total size of that input.

The rest of the paper describes how to build the parsing library step by
step: production of results in a online way (section~\ref{sec:applicative}), map the
input to these results and manage the incremental computation of intermediate
state (section~\ref{sec:input}) and treat disjunction and error correction (section~\ref{sec:parsing}).
In section~\ref{sec:sublinear} we will tackle the problem of incremental parsing of
repetition. We discuss and compare our approach to alternatives in
section~\ref{sec:relatedWork} and conclude (section \ref{sec:conclusion}).
    
%include Applicative.lhs
%include Input.lhs
%include Choice.lhs
%include Sublinear.lhs

\section{Related work}
\label{sec:relatedWork}

The litterature on analysis of programs, incremental or not, is so abundant
that a complete survey would deserve its own treatment. Here we will compare our
approach to some of the closest alternatives.

\subsection{Incremental parsing in development environments} 


\citet{ghezzi_incremental_1979}
\citet{ghezzi_augmenting_1980}
\citet{wagner_efficient_1998} 
\citet{bahlke_psg_1986} 


State matching approaches.
This does not apply for combinator parser library, because the parser
state is not really observable.


We have a much more modest approach, in the sense that we do not attempt to
reuse the (right-bound) nodes that were created in previous parsing runs. Another drawback is
that we assume that the window moves by incremental steps. If the user jumps
back and forth the beginning and the end of the file, while making changes at
the beginning, our approach will force reparsing the whole file every time a
change is made at the beginning followed by a jump to the end of the file.


Despite extensive research dating as far back as 30 years ago, somehow, none of
these solutions have caught up in the mainstream. Editors typically work using
regular expressions for syntax highlighting at the lexical level (Emacs, Vim,
Textmate, \ldots{}) and integrated development environments run a full compiler
in the background for syntax level feedback (Eclipse).

We might argue that early solutions offered little
benefit in comparison to their implementation cost. Our approach is
much simpler. 

One might argue that node reuse is an essential component of incremental
parsing. However, it is notable that programming languages syntaxes are often
specified with a forward reading approach. A consequence is that a small change
in the beginning of the file can completely invalidate the parse tree obtained
in the previous run. A simple example is the opening of a comment. (For example,
while editing an Haskell source file, typing \verb!{-! implies that the rest of
the file becomes a comment up to the next \verb!-}!.) Hence, trying to reuse
right-bound parts of the parse tree seems to be optimizing for a special case.
This is not very suitable in an interactive system where users expect consistent
response times.

Another downside of our approach is that it requires the consumption of the AST
to be done in pre-order. If this is not the case, the online property becomes
useless. For example, if one wishes to apply a sorting algorithm before
displaying the output, this will force the whole input to be parsed before
displaying the first element of the input. In particular, the arguments to the
|Pure| constructor must not perform such operations on its arguments. Ideally,
it should be a simple constructor. This leaves many opportunites for the user of
the library to destroy its incremental properties.

\subsection{Incremental parsing in natural language processing} 

In natural language processing, a parsing alagorithm is deems incremental if it
reads the input one token at a time and calculates all the possible consequences
of the token, before the net token is read. (Citation? (quoted from Krasimir))

We note that there is no notion of AST update in this definition.

\textmeta{Does this correspond to the online property or the other?}

\subsection{Incremental computation}

An alternative approach would be to build the library as a plain parser on top
of a generic incremental computation system. The main drawback is that there
currently exists no such off-the-shelf such system for Haskell. The closest
matching solution is provided by \citet{carlsson_monads_2002}, and relies
heavily on explicit threading of computation through monads and explict
reference for storage of inputs and intermediate results. This imposes an
imperative description of the incremental algorithm, which does not match our
goals. Furthermore, in the case of parsing, the inputs would be the individual
symbols. This means that, not only their contents will change from one run to
another, but their numbers will as well. One then might want to rely on laziness,
as we do, to avoid depending unnecessarily on the tail of the input, but then we
hit the problem that the algorithm must be described imperatively.
Therefore, we think that such an approch would be awkward, if not unapplicable.

\begin{meta}
Plugging an attribute evaluator on top of this?
This does not really work since we do not reuse the result. 
\citet{saraiva_functional_2000}

We could put a semantic layer by replacing the constructors with arbitrary
semantic functions. Incrementality is not guaranteed then.
\end{meta}


\subsection{Parser combinators}

Our approach is firmly anchored in the tradition of parser combinator libraries
\citep{hutton_monadic_1998}, and particularly close to the version of
\citet{hughes_polish_2003}.

The introduction of the |Susp| operator is directly inspired by
\citet{claessen_parallel_2004}. We presented our implementation as a version of
polish parsers extended with an evaluation precedure ``by-value'', but we could
equally have started with parallel parsing processes and extended them with
``by-name'' evaluation. The combination of both evaluation techniques is unique
to our library.

While error correction mechanism was developed independently, it bears many
similarities with that presented by \citet{swierstra_fast_1999}: they also
associate some variant of progress information to parsers and rely on thinning
and laziness to explore the tree of all possible parses.


\subsection{Summary}


We can summarize the unique points of our approach as follows:

\begin{itemize}
\item
  simple

\item
  no tree update

\item
  taking advantage of lazy evaluation: no startup cost to parse the
  whole file the first time a file is loaded.

\item 
  in a parsing combinator library

\end{itemize}
\begin{meta}
What does Visual Haskell do?

\end{meta}

\subsection {Future work}

Athough it is trivial to add a \emph{failure} combinator to the library
presented here, we refrained from doing so because it can lead to failing
parsers. However, in practise this can most often be emulated by a repetitive
usage of the |Dislike| combinator. This can lead to some performance loss, as
the failing branch. Indeed, if one takes things to the extreme and tries to use
the fixpoint (|fix Dislike|) to represent failure, it will lead to
nontermination. This is due to our use of strict integers in the progress
information. We have chosen this representation to emphasize the dynamic
programming aspect of our solution, but it might be more efficient to represent
progress by a mere interleaving of |Shift| and |Dislike| constructors.

Our library suffers from the usual drawbacks of parser combinator approaches.
In particular, it is impossible to write left-recursive parsers, because they
yield a non-terminating loop in the parsing algorithm. We could proceed as
\citet{baars_typed_2009} and represent the grammar rules and transform them on
the fly. It is interesting to note however that we could represent traditional
left-recursive parsers as long as they either consume or \emph{produce} data,
provided the progress information is indexed by the number of |Push|es in
addition to |Shift|s.

Finally, we might want to re-use the right hand side of previous parses. This could
be done by keeping the parsing results \emph{for all possible prefixes}. Proceeding
in this fashion would avoid the cahotic situation where a small modification might
invalidate all the parsing work that follows it, since we take in account \emph{all}
possible prefixes ahead of time.

\section{Results}

We carried out development of a parser combinator library for incremental
parsing with support for error correction. We argumented that, using suitable
data structures for the output, the complexity of parsing (without error
correction) is $O(log~m + n)$ where $m$ is the number of tokens in the state we
resume from and $n$ is the number of tokens to parse. Parsing an increment of
constant size has an amortized complexity of $O(1)$.

The parsing library presented in this paper is 
used in the Yi editor to help matching parenthesis and layout the Haskell
functions, and environment delimiters as well as parenthetical
symbols were matched in the \LaTeX{} source.

This paper and accompanying source code have been edited in this environment.


\section{Conclusion}
\label{sec:conclusion}

We have shown that the combination of three techniques
achieve the goal of incremental parsing.

\begin{enumerate}

\item In a lazy setting, the combination of online production of results and
saving intermediate results provide incrementality;

\item \textmeta {not sure what to write about error-correction}

\item Provided that they are carefully constructed to preserve laziness, tree
structures can always replace lists in functional programs. Doing so can improve
the complexity class of algorithms.

\end{enumerate}

While these techniques work together here, we believe that they are valuable
independent on each other. In particular, our error correction scheme can be
replaced by an other one without invalidating the approach. 

Also, while functional data structures are often presented in a way that
ignores their lazy constructions (and thus are not always as good as plain
lists), we have shown that this need not be the case. The simple structure
presented here has tree applications in our system only, and is virtually always
an improvement over plain lists.




\acks

We thank Koen Claessen for persuading us to write this paper, and for his
unfading support throughout the writing process. This paper was greatly improved
by his comments on early and late drafts. Krasimir Angelov helped sorting out
the notions of incremental parsing.
\textmeta{!!!Your name here!!!}

\bibliographystyle{mybst}
\bibliography{../Zotero.bib}


\end{document}
