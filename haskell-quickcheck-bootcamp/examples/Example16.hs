-- Example 16: パターン5「テストオラクル (model-based)」
--
-- 「正しいと信じられる別実装」と結果を比べます。
--   自作の速い実装  vs  標準ライブラリの素朴な実装
--   最適化した実装  vs  最適化前の実装
--   新しい実装      vs  古い実装 (リファクタの安全網)
--
-- プロパティを考えなくてよいので、一番手軽で一番強力です。
--
-- 実行: runghc Example16.hs
module Main (main) where

import qualified Data.List as L
import Test.QuickCheck

------------------------------------------------------------
-- 自作クイックソート vs Data.List.sort
------------------------------------------------------------
myQuickSort :: Ord a => [a] -> [a]
myQuickSort []     = []
myQuickSort (p:xs) = myQuickSort smaller ++ [p] ++ myQuickSort larger
  where smaller = [ x | x <- xs, x <= p ]
        larger  = [ x | x <- xs, x >  p ]

prop_quickSortMatchesModel :: [Int] -> Property
prop_quickSortMatchesModel xs = myQuickSort xs === L.sort xs

------------------------------------------------------------
-- 自作 reverse (foldl 版) vs 標準の reverse
------------------------------------------------------------
myReverse :: [a] -> [a]
myReverse = foldl (flip (:)) []

prop_reverseMatchesModel :: [Int] -> Property
prop_reverseMatchesModel xs = myReverse xs === reverse xs

------------------------------------------------------------
-- 「速いが読みにくい実装」 vs 「遅いが明らかに正しい実装」
------------------------------------------------------------
-- 仕様: リストの各位置までの累積和
-- 素朴な実装 (O(n^2)) は明らかに正しい
scanSumSlow :: [Int] -> [Int]
scanSumSlow xs = [ sum (take n xs) | n <- [1 .. length xs] ]

-- 速い実装 (O(n)) はバグが入りやすい
scanSumFast :: [Int] -> [Int]
scanSumFast = drop 1 . scanl (+) 0

prop_scanSumSame :: [Int] -> Property
prop_scanSumSame xs = scanSumFast xs === scanSumSlow xs

------------------------------------------------------------
-- オラクルが「ずれている」例 (わざと失敗させる)
------------------------------------------------------------
-- 自作 nub は「後ろの重複を残す」実装にしてしまった
myNubWrong :: Eq a => [a] -> [a]
myNubWrong = reverse . L.nub . reverse

prop_nubMatchesModel :: [Int] -> Property
prop_nubMatchesModel xs = myNubWrong xs === L.nub xs

main :: IO ()
main = do
  putStr "quickSort vs sort   : " >> quickCheck prop_quickSortMatchesModel
  putStr "myReverse vs reverse: " >> quickCheck prop_reverseMatchesModel
  putStr "scanSum fast vs slow: " >> quickCheck prop_scanSumSame
  putStrLn ""
  putStrLn "--- oracle mismatch (fails on purpose) ---"
  quickCheck prop_nubMatchesModel

-- オラクル法が特に効く場面:
--   * パフォーマンス改善のリファクタ (前の実装をオラクルにする)
--   * キャッシュ層の導入 (キャッシュなしをオラクルにする)
--   * 並行版の実装 (逐次版をオラクルにする)
--   * 別言語からの移植 (移植元をオラクルにする)
--
-- 注意:
--   オラクルが間違っていたら、テストも間違います。
--   「明らかに正しいが遅い」実装を選ぶのがコツです。
