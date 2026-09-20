-- Example 03: 単体テストとプロパティの違い
--
-- 同じ関数を「具体例で確かめる」のと「性質で確かめる」のを並べて比べます。
--
-- 実行: runghc Example03.hs
module Main (main) where

import Data.List (sort)
import Test.QuickCheck

-- テスト対象: 2つのソート済みリストをマージする。
-- ただし1行バグが入っています。どこか分かりますか?
merge :: [Int] -> [Int] -> [Int]
merge [] ys = ys
merge xs [] = xs
merge (x:xs) (y:ys)
  | x < y     = x : merge xs (y:ys)
  | otherwise = y : merge xs ys   -- ★バグ: xs ではなく (x:xs) を渡すべき
------------------------------------------------------------
-- 1. 具体例によるテスト (いわゆる単体テスト)
------------------------------------------------------------
-- 人間が思いつく「代表的な入力」を手で並べます。
unitTests :: [(String, Bool)]
unitTests =
  [ ("empty + empty",       merge [] []         == [])
  , ("empty + nonempty",     merge [] [1,2,3]    == [1,2,3])
  , ("nonempty + empty",     merge [1,2,3] []    == [1,2,3])
  , ("interleaved",          merge [1,3] [2,4]   == [1,2,3,4])
  ]

------------------------------------------------------------
-- 2. プロパティによるテスト
------------------------------------------------------------
-- 「どんな入力でも成り立つはずのこと」を書きます。
-- ここでは「ソート済み同士をマージした結果は、両方を足してソートしたものと等しい」。
prop_mergeIsSort :: [Int] -> [Int] -> Bool
prop_mergeIsSort xs ys =
  merge (sort xs) (sort ys) == sort (xs ++ ys)

main :: IO ()
main = do
  putStrLn "--- unit tests (example based) ---"
  mapM_ report unitTests
  putStrLn ""
  putStrLn "--- property test ---"
  quickCheck prop_mergeIsSort
  where
    report (name, ok) =
      putStrLn ((if ok then "PASS " else "FAIL ") ++ name)

-- 結果:
--   単体テストは4つとも PASS します。上に並べた例はどれもバグを踏みません。
--   プロパティテストは失敗し、[0,0] のような反例を出します。
--   (同じ値が両方のリストにあると、片方が消えてしまうバグです)
--
-- 教訓:
--   単体テストは「自分が思いついた入力」しか試せません。
--   思いつかなかった入力にバグが潜んでいると、永遠に見つかりません。
--   プロパティテストは「入力を考えるのをやめて、性質だけ書く」ことで、
--   自分では思いつかない入力を機械に探させます。
