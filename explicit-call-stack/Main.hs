module Main where

import GHC.Stack

main = foo

foo = bar

bar = currentCallStack >>= (putStrLn . renderStack)
