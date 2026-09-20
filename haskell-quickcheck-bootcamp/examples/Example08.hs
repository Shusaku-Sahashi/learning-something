-- Example 08: 実行設定を変える (quickCheckWith と Args)
--
-- quickCheck は内部で stdArgs という設定を使っています。
-- quickCheckWith に自分の設定を渡せば挙動を変えられます。
--
-- 実行: runghc Example08.hs
module Main (main) where

import Test.QuickCheck

prop_plusComm :: Int -> Int -> Bool
prop_plusComm x y = x + y == y + x

-- 大きい値でしか壊れないプロパティ (Int の範囲では実際には壊れませんが、
-- 「サイズを上げると何が変わるか」を見るためのサンプルです)
prop_showLength :: Int -> Bool
prop_showLength x = length (show x) <= 5

main :: IO ()
main = do
  putStrLn "--- default (100 tests) ---"
  quickCheck prop_plusComm

  putStrLn "--- raise to 10000 tests ---"
  quickCheckWith stdArgs { maxSuccess = 10000 } prop_plusComm

  putStrLn "--- maxSize = 10 : only small values ---"
  quickCheckWith stdArgs { maxSize = 10, maxSuccess = 200 } prop_showLength

  putStrLn "--- maxSize = 1000 : big values appear, so it fails ---"
  quickCheckWith stdArgs { maxSize = 1000, maxSuccess = 200 } prop_showLength

  putStrLn "--- chatty = False : stay quiet ---"
  quickCheckWith stdArgs { chatty = False } prop_plusComm
  putStrLn "  (nothing was printed because chatty = False)"

-- Args の主なフィールド:
--
--   maxSuccess     :: Int   何件通れば合格とするか        (既定 100)
--   maxSize        :: Int   生成サイズの上限              (既定 100)
--   maxDiscardRatio:: Int   捨てた入力の許容比率          (既定 10, Ch6)
--   maxShrinks     :: Int   縮小の最大試行回数            (既定 maxBound)
--   chatty         :: Bool  進捗を表示するか              (既定 True)
--   replay         :: Maybe (QCGen, Int)  乱数を固定する  (Example 86)
--
-- 実務での目安:
--   開発中           : maxSuccess = 100 (既定) のまま、速く回す
--   CI の通常ジョブ  : maxSuccess = 500 〜 1000
--   夜間バッチ       : maxSuccess = 100000, maxSize を上げる
--
-- 「サイズ (size)」は QuickCheck が生成器に渡すパラメータで、
-- 0 から maxSize まで少しずつ増えていきます。
-- リストなら長さ、数値なら絶対値の目安として使われます (Ch3 で詳しく扱います)。
