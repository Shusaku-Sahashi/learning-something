-- | 自分が実装した Exercise.Part1.Parser を QuickCheck で検証する。
-- `cabal test part1` で実行する。まだ実装していない関数を呼ぶプロパティは
-- 例外 (Exception) として失敗表示されるので、それを1つずつ潰していく。
module Main (main) where

import Control.Monad (unless)
import Exercise.Part1.Parser
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
