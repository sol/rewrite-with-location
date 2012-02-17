# Proposal: An extensible mechanism for source locations in library code

Assertions marked with (?) need further clarification.

I propose a solution that is similar to [JHC's `SRCLOC_ANNOTATE`
pragma][jhc-srcloc-annotate], but slightly more general.

    error :: String -> a
    errorLoc :: Location -> String -> a
    {-# REWRITE_WITH_LOCATION error errorLoc -#}

    data Location

## Use cases

 * Locations for failing test cases in a test framework
 * Locations for log messages
 * assert/error/undefined

## Properties

Compilers that do not support the pragma will use the original implementation

Users can build new combinators based on this mechanism, like:

    myError :: a
    myError = error "some error message"

    myErrorLoc :: Location -> a
    myErrorLoc loc = errorLoc loc "some error message"

    {-# REWRITE_WITH_LOCATION myError myErrorLoc -#}

In contrast, this is not possible with the current mechanism used for assert,
e.g. `assertNot` with

    assertNot = assert . not

will not include locations information about the call site of `assertNot` in
it's error message.

## Details

 1. Both arguments to `REWRITE_WITH_LOCATION` have to be in scope
 1. The type of the second argument must be `Location -> a`, where `a` is the
    type of the first argument

## Disadvantages

People could misuse this feature to change the semantics of their code (with
great power comes great responsibility!).

## Comparison with other approaches

### Template Haskell

It is possible to achieve something like this with Template Haskell.

Disadvantages:

 * code that uses Template Haskell has an additional runtime dependency ([`template-haskell`][template-haskell])
 * is not valid Haskell98
 * is not available for all architectures (?)

[template-haskell]: http://hackage.haskell.org/package/template-haskell "Template Haskell on Hackage"
[jhc-srcloc-annotate]: http://repetae.net/computer/jhc/jhc.shtml#new-extensions


### Explicit call stacks

Disadvantages:

 * May have a bigger runtime overhead and hence be disabled in production code (?)
 * Are not available yet (?)