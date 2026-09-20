-- | 模範解答 (Solutions.Part2) が QuickCheck のプロパティを
-- すべて満たすことを確認するためのテスト。
module Main (main) where

import Control.Monad (unless)
import Solutions.Part2
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
