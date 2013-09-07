# Proposal: Source locations for GHC

> A simple and extensible mechanism for source locations in library code

## Problem
 * When a partial function fails, we have no clue _where_ things went wrong!
 * We can try to avoid the use of partial functions in our own code, but what
   about third party libraries (`base`, GHC API)?

For the specific case of `undefined` [Haskell 2010 states] [1] that

> It is expected that compilers will recognize this and insert error messages
> that are more appropriate to the context in which `undefined` appears.

But GHC currently does not follow this suggestion.

[1]: http://www.haskell.org/onlinereport/haskell2010/haskellch9.html#verbatim-238 "Haskell 2010"

## Design goals

A solution to this problem should

 * work in GHCi
 * work in production code
 * work on all platforms
 * impose zero runtime overhead
 * not rely on language extensions (at least not on the call site, so that it
   can be used for `Prelude` functions)

## Proposed solution

JHC addresses the issue with a pragma that rewrites calls to annotated
functions (see [documentation of JHC's `SRCLOC_ANNOTATE`
pragma][jhc-srcloc-annotate] for details).

We propose a solution that is similar to JHC's approach, but slightly more
general.  We introduce a pragma

```haskell
{-# REWRITE_WITH_LOCATION src dst #-}
```
where

 1. `src` has to refer to a function in the same module, `dst` has to be in
    scope
 1. the type of `dst` must be `Location -> a`, where `a` is the type of `src`

GHC then automatically replaces all calls to `src` with calls to `dst`,
automatically providing the first argument based on the location of the call
site.

Compilers that do not support the pragma will use the original implementation.

## Use cases

 * Location for log messages
 * Location for failing test cases
 * `assert`/`error`/`undefined`

## Examples
For the purpose of this examples we use `String` as `Location`.  But a final
implementation may use a proper location type (e.g. something like
[`Language.Haskell.TH.Syntax.Loc`](http://hackage.haskell.org/packages/archive/template-haskell/2.7.0.0/doc/html/Language-Haskell-TH-Syntax.html#t:Loc)).

### Location for log messages

~~~ {.haskell}
module Logging where

import GHC.Err (Location)

logError :: String -> IO ()
logError message = putStrLn message

logErrorLoc :: Location -> String -> IO ()
logErrorLoc loc message = putStrLn (loc ++ ": " ++ message)
{-# REWRITE_WITH_LOCATION logError logErrorLoc #-}
~~~

```haskell
module Main (main) where
import Logging

main :: IO ()
main = logError "Something went wrong!"
```

```
$ ghci Main.hs
*Main> main
Main.hs:5:8-15: Something went wrong!
```

### Call site for error / undefined

The described mechanism can be used to add call site locations to `error` and
`undefined`.

```haskell
module GHC.Err (Location, error, errorLoc, undefined, undefinedLoc) where

type Location = String

error :: String -> a
error = errorCall

errorLoc :: Location -> String -> a
errorLoc loc s = errorCall (loc ++ ": " ++ s)
{-# REWRITE_WITH_LOCATION error errorLoc #-}

undefined :: a
undefined =  error "Prelude.undefined"

undefinedLoc :: Location -> a
undefinedLoc = (`errorLoc` "Prelude.undefined")
{-# REWRITE_WITH_LOCATION undefined undefinedLoc #-}

errorCall :: String -> a
errorCall s = raise# (errorCallException s)
```
## Manual lifting of annotated functions

It's possible to manually lift functions that use `error` like so:

```haskell
import GHC.Err

head :: [a] -> a
head (x:_) = x
head    _  = error "Prelude.head: empty list"

headLoc :: Location -> [a] -> a
headLoc loc (x:_) = x
headLoc loc    _  = errorLoc loc "Prelude.head: empty list"
{-# REWRITE_WITH_LOCATION head headLoc #-}
```

In contrast, this is not possible with the current mechanism used for assert,
e.g. `assertNot` with

```haskell
assertNot = assert . not
```

will not include location information about the call site of `assertNot` in
it's error message.

## Comparison with other approaches

### Template Haskell

It is possible to achieve something like this with Template Haskell.  However,
the use of Template Haskell imposes the following limitations:

 * does not work on all platforms (requires GHCi)
 * relies on language extensions (`-XTemplateHaskell`)
 * imposes an additional runtime dependency
   ([`template-haskell`][template-haskell])
 * uses different syntax which may be unappealing to users (e.g. Template
   Haskell splices can't be used in infix notation)

[template-haskell]: http://hackage.haskell.org/package/template-haskell "Template Haskell on Hackage"
[jhc-srcloc-annotate]: http://repetae.net/computer/jhc/jhc.shtml#new-extensions


### Explicit call stacks

It is possibel to get an explicit call stack with
[`GHC.Stack.currentCallStack`](http://hackage.haskell.org/packages/archive/base/4.6.0.1/doc/html/GHC-Stack.html#v:currentCallStack).

From the documentation:

> The implementation uses the call-stack simulation maintined by the profiler,
> so it only works if the program was compiled with -prof and contains suitable
> SCC annotations (e.g. by using -fprof-auto).

This has the following implications:

 * does not work in GHCi
 * does not work in production code
 * imposes significant runtime overhead
 * is not enabled by default

## Conclusion

In addition to the stated design goals the proposed solution is

 * trivial to implement
 * available now

The approach has been discussed before, but was dismissed with the assumption
that the user actually wants stack traces.  However, there are use cases where
we are not even interested in a stack trace, e.g. _logging_ and _failing test
cases_.
