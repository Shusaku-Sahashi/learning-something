-- Example 07: verboseCheck で生成された値を覗く
--
-- 「本当にちゃんとした入力が来ているのか?」を確かめたいときは
-- quickCheck の代わりに verboseCheck を使います。
--
-- 実行: runghc Example07.hs
module Main (main) where

import Test.QuickCheck

prop_absNonNegative :: Int -> Bool
prop_absNonNegative x = abs x >= 0

-- わざと失敗させて、縮小の過程まで見るプロパティ
prop_smallList :: [Int] -> Bool
prop_smallList xs = length xs < 3

main :: IO ()
main = do
  putStrLn "--- verboseCheck: show each generated value (5 only) ---"
  -- そのまま verboseCheck すると 100 件表示されて画面が埋まるので、
  -- maxSuccess を絞ります (Args の詳細は Example 08)。
  verboseCheckWith stdArgs { maxSuccess = 5 } prop_absNonNegative
  putStrLn ""

  putStrLn "--- verboseCheck: watch a failure and its shrinking ---"
  verboseCheckWith stdArgs { maxSuccess = 20 } prop_smallList

-- 出力の読み方:
--
--   Passed:
--   0
--   Passed:
--   -1
--   ...
--     -> 1件ごとに「生成された値」と「結果」が出る
--
--   失敗後は
--   Failed:
--   [1,2,3,4]
--   Passed:              <- 縮小候補を試したが、性質を満たしてしまった (縮小失敗)
--   []
--   Failed:              <- 縮小候補が再び失敗した (縮小成功。これを採用して続行)
--   [1,2,3]
--   ...
--     -> Failed が出るたびに、より小さい反例に進んでいく
--
-- verboseCheck は「なぜかテストが通ってしまう」ときの最初の調査手段です。
-- 生成器を自作したあとは、一度必ず覗いてください (Ch4)。
--
-- 縮小の過程だけ見たいなら verboseShrinking もあります (Example 58)。
