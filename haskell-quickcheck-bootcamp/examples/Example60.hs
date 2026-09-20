-- Example 60: 条件が厳しすぎるとどうなるか (Gave up)
--
-- (==>) の一番の落とし穴です。
--
-- 実行: runghc Example60.hs
module Main (main) where

import Data.List (sort)
import Test.QuickCheck

-- ゆるい条件: ほとんどの入力が通る
prop_loose :: [Int] -> Property
prop_loose xs = length xs /= 0 ==> length xs > 0

-- 厳しい条件: ソート済みのリストだけを使いたい
-- ランダムなリストが偶然ソート済みである確率は、長さが伸びるほど急速に下がります。
prop_strict :: [Int] -> Property
prop_strict xs = isSorted xs ==> isSorted (reverse (reverse xs))

-- もっと厳しい条件: 長さ 5 以上かつソート済み
prop_verystrict :: [Int] -> Property
prop_verystrict xs =
  length xs >= 5 && isSorted xs ==> isSorted xs

isSorted :: [Int] -> Bool
isSorted ys = and (zipWith (<=) ys (drop 1 ys))

-- ★ 正しい直し方: 条件で弾くのではなく、生成器で作る
prop_fixed :: Property
prop_fixed =
  forAll (sort <$> arbitrary) $ \xs ->
    length (xs :: [Int]) >= 5 ==> isSorted xs

-- さらに良い直し方: 長さも生成器で保証する
prop_best :: Property
prop_best =
  forAll genSortedAtLeast5 isSorted
  where
    genSortedAtLeast5 = do
      n  <- choose (5, 20)
      xs <- vectorOf n arbitrary
      pure (sort (xs :: [Int]))

main :: IO ()
main = do
  putStrLn "--- loose precondition: fine ---"
  quickCheck prop_loose
  putStrLn ""

  putStrLn "--- strict precondition: many discards ---"
  quickCheck prop_strict
  putStrLn ""

  putStrLn "--- very strict: QuickCheck gives up ---"
  quickCheck prop_verystrict
  putStrLn ""

  putStrLn "--- raising maxDiscardRatio helps a bit, but it is slow ---"
  quickCheckWith stdArgs { maxDiscardRatio = 1000 } prop_verystrict
  putStrLn ""

  putStrLn "--- the right fix: generate sorted lists ---"
  quickCheck prop_fixed
  putStrLn ""

  putStrLn "--- even better: generate the length too, no discards at all ---"
  quickCheck prop_best
  putStrLn ""

  putStrLn "--- how rare is a sorted list, by length? ---"
  mapM_ measure [0, 1, 2, 3, 5, 8]
  where
    measure n = do
      xs <- sequence (replicate 2000 (generate (vectorOf n (arbitrary :: Gen Int))))
      let hits = length (filter isSorted xs)
      putStrLn ("  length " ++ show n ++ ": " ++ show hits ++ " / 2000 are sorted")

-- 読み方:
--   *** Gave up! Passed only 12 tests; 1000 discarded tests.
--
--   「1000 個の入力を捨てたが、条件を満たすものが 12 個しか見つからなかった」
--   これは失敗ではありませんが、テストとしては役に立っていません。
--
-- maxDiscardRatio (既定 10) の意味:
--   「maxSuccess の maxDiscardRatio 倍」まで捨てたら諦める。
--   既定なら 100 * 10 = 1000 個捨てた時点で Gave up になります。
--
-- 対処の優先順位:
--   1. 生成器を書き直して、条件を満たす値を直接作る  <- これが正解
--   2. Modifier を使う (Example 61 以降)            <- 既製品があるなら最速
--   3. maxDiscardRatio を上げる                    <- 最後の手段。遅いだけ
--
-- 「条件を満たす確率が 1/10 を下回ったら生成器を書き直す」
-- くらいの感覚で運用すると、テストが健全に保てます。
