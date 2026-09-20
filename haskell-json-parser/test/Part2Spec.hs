-- | 自分が実装した Exercise.Part2.Parser を QuickCheck で検証する。
-- `cabal test part2` で実行する。
module Main (main) where

import Control.Monad (unless)
import Exercise.Part2.Parser
import System.Exit (exitFailure)
import Test.QuickCheck (isSuccess, quickCheckResult)

main :: IO ()
main = do
  results <-
    sequence
      [ run "prop_genParseJString" prop_genParseJString
      , run "prop_genParseJNumber" prop_genParseJNumber
      , run "prop_genParseJArray" prop_genParseJArray
      , run "prop_genParseJObject" prop_genParseJObject
      , run "prop_genParseJSON" prop_genParseJSON
      ]
  unless (and results) exitFailure
  where
    run name prop = do
      putStrLn $ "== " <> name <> " =="
      isSuccess <$> quickCheckResult prop
