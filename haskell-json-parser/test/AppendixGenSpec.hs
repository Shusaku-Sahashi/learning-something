-- | docs/appendix-quickcheck.md の腕試し用テスト。
-- 自分で実装した Exercise.Appendix.Gen (ジェネレータ) を、
-- 自分ですでに実装した Exercise.Part1.Parser (パーサ) を使って
-- ラウンドトリップ検証する。`cabal test appendix-gen` で実行する。
--
-- Part1 がまだ未実装なら、先に `cabal test part1` が通る状態にしてから
-- 取り組んでください。
module Main (main) where

import Control.Monad (unless)
import Exercise.Appendix.Gen
import Exercise.Part1.Parser (parseJSON)
import System.Exit (exitFailure)
import Test.QuickCheck

prop_ownGenRoundTrips :: Property
prop_ownGenRoundTrips = forAllShrink (sized jValueGen) shrink $ \value -> do
  json <- stringify value
  return . counterexample (show json) . (== Just value) . parseJSON $ json

main :: IO ()
main = do
  putStrLn "== prop_ownGenRoundTrips =="
  ok <- isSuccess <$> quickCheckResult prop_ownGenRoundTrips
  unless ok exitFailure
