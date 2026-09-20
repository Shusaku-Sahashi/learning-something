-- Example 17: パターン6「メタモルフィック関係」
--
-- 「出力の正解は分からないが、入力をこう変えたら出力はこう変わるはず」
-- という関係を書きます。正解を計算できない関数に対しても書けるのが強みです。
--
-- 実行: runghc Example17.hs
module Main (main) where

import Data.List (sort)
import Test.QuickCheck

------------------------------------------------------------
-- 例1: sort
------------------------------------------------------------
-- 「ソート結果」を予測せずに済む書き方です。
-- 入力に要素を1つ足したら、出力にもその要素が1つ増えるだけ。
prop_sortInsert :: Int -> [Int] -> Property
prop_sortInsert x xs =
  sort (x : xs) === insertSorted x (sort xs)
  where
    insertSorted y []     = [y]
    insertSorted y (z:zs)
      | y <= z    = y : z : zs
      | otherwise = z : insertSorted y zs

-- 入力を並べ替えても、ソート結果は変わらない。
prop_sortIgnoresOrder :: [Int] -> Property
prop_sortIgnoresOrder xs = sort xs === sort (reverse xs)

-- 全要素に単調増加な関数を適用しても、順序関係は保たれる。
prop_sortMonotoneMap :: [Int] -> Property
prop_sortMonotoneMap xs = sort (map (* 2) xs) === map (* 2) (sort xs)

------------------------------------------------------------
-- 例2: 検索スコア (正解を計算できない典型)
------------------------------------------------------------
-- 「クエリと文書の関連度」を返す関数。正解のスコアは誰にも分かりません。
-- でも関係なら書けます。
score :: String -> String -> Int
score query doc = length [ () | w <- words doc, w `elem` words query ]

-- 関係1: 文書に一致する単語を足したら、スコアは下がらない。
prop_scoreMonotone :: String -> String -> Property
prop_scoreMonotone query doc =
  not (null (words query)) ==>
    score query (doc ++ " " ++ head (words query)) >= score query doc

-- 関係2: 文書を2つつなげたスコアは、それぞれのスコアの和。
prop_scoreAdditive :: String -> String -> String -> Property
prop_scoreAdditive query d1 d2 =
  score query (d1 ++ " " ++ d2) === score query d1 + score query d2

------------------------------------------------------------
-- 例3: フィルタの補集合関係
------------------------------------------------------------
prop_filterPartition :: [Int] -> Property
prop_filterPartition xs =
  length (filter even xs) + length (filter (not . even) xs) === length xs

main :: IO ()
main = do
  putStrLn "--- sort ---"
  putStr "insert relation   : " >> quickCheck prop_sortInsert
  putStr "order-independent : " >> quickCheck prop_sortIgnoresOrder
  putStr "monotone map      : " >> quickCheck prop_sortMonotoneMap
  putStrLn ""
  putStrLn "--- score (no known correct answer) ---"
  putStr "monotone          : " >> quickCheck prop_scoreMonotone
  putStr "additive          : " >> quickCheck prop_scoreAdditive
  putStrLn ""
  putStrLn "--- filter ---"
  putStr "partition         : " >> quickCheck prop_filterPartition

-- メタモルフィック関係の探し方 (テンプレート):
--   入力を並べ替えたら?        -> 結果は同じ / 同じように並べ替わる
--   入力を1つ足したら?          -> 結果は単調に増える / 1つ増える
--   入力を2つに分けたら?        -> 結果は合成できる (分配則)
--   入力を定数倍したら?          -> 結果も定数倍になる
--   入力を空にしたら?            -> 単位元が返る
--   同じ入力を2回与えたら?       -> 同じ結果 (決定性)
--
-- 機械学習モデルや検索ランキングなど、
-- 「正解が定義できないシステム」のテストでよく使われる手法です。
