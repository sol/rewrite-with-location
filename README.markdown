# Proposal: An extensible mechanism for source locations in library code

We propose a solution that is similar to [JHC's `SRCLOC_ANNOTATE`
pragma][jhc-srcloc-annotate], but slightly more general.

```haskell
type Location = String
```

```haskell
error :: String -> a
errorLoc :: IO Location -> String -> a
{-# REWRITE_WITH_LOCATION error errorLoc #-}
```
In contrast to JHC's solution, we wrap the `Location` value in `IO`, so that it
is easier to reason about code.

## Use cases

 * Locations for failing test cases in a test framework
 * Locations for log messages
 * assert/error/undefined

## Properties

Compilers that do not support the pragma will use the original implementation.

Users can build new combinators based on this mechanism, e.g.:

```haskell
myError :: a
myError = error "some error message"

myErrorLoc :: IO Location -> a
myErrorLoc loc = errorLoc loc "some error message"

{-# REWRITE_WITH_LOCATION myError myErrorLoc #-}
```

In contrast, this is not possible with the current mechanism used for assert,
e.g. `assertNot` with

```haskell
assertNot = assert . not
```

will not include locations information about the call site of `assertNot` in
it's error message.

## Details

 1. The first argument to `REWRITE_WITH_LOCATION` has to refer to a function in
    the same module, the second argument has to be in scope
 1. The type of the second argument to `REWRITE_WITH_LOCATION` must be `IO
    Location -> a`, where `a` is the type of the first argument.

## Modifications

It might be a good idea to have a proper `Location` type, instead of using
`String` (something like
[`Language.Haskell.TH.Syntax.Loc`](http://hackage.haskell.org/packages/archive/template-haskell/2.7.0.0/doc/html/Language-Haskell-TH-Syntax.html#t:Loc)).
This would allow things like filtering log messages by originating module.

## Disadvantages

People could misuse this feature to change the semantics of their code (with
great power comes great responsibility!).

## Comparison with other approaches

### CPP

> TODO

### Template Haskell

It is possible to achieve something like this with Template Haskell.

#### Disadvantages

 * code that uses Template Haskell has an additional runtime dependency ([`template-haskell`][template-haskell])
 * is not valid Haskell98
 * is not available for all architectures (depends on GHCi!)
 * Usage is "opt-in." A library author must explicitly use the TH version of the function with usage information,
   as opposed to this proposal which would automatically add location information for existing code.
 * It requires a different syntax which may be unappealing to users.

[template-haskell]: http://hackage.haskell.org/package/template-haskell "Template Haskell on Hackage"
[jhc-srcloc-annotate]: http://repetae.net/computer/jhc/jhc.shtml#new-extensions


### Explicit call stacks

It is possibel to get an explicit call stack with
[`GHC.Stack.currentCallStack`](http://hackage.haskell.org/packages/archive/base/4.5.1.0/doc/html/GHC-Stack.html#v:currentCallStack).

#### Disadvantages

From the documentation:

> The implementation uses the call-stack simulation maintined by the profiler,
> so it only works if the program was compiled with -prof and contains suitable
> SCC annotations (e.g. by using -fprof-auto).

This has the following implications:

 * Not enabled by default
 * Does not work within GHCi
