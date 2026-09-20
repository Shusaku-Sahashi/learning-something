-- Example 10: 複数の条件を組み合わせる
--
-- 1つのプロパティで複数のことを確かめたいときの道具です。
--
-- 実行: runghc Example10.hs
module Main (main) where

import Data.List (sort)
import Test.QuickCheck

-- (.&&.) : かつ。両方成り立つ必要がある。
--          どちらが失敗したか分かるように counterexample と併用すると良い。
prop_sortBasics :: [Int] -> Property
prop_sortBasics xs =
  counterexample "length changed"     (length (sort xs) === length xs)
    .&&.
  counterexample "result is not sorted" (property (isSorted (sort xs)))
    .&&.
  counterexample "sort is not idempotent"         (sort (sort xs) === sort xs)

isSorted :: [Int] -> Bool
isSorted ys = and (zipWith (<=) ys (drop 1 ys))

-- (.||.) : または。どちらか成り立てばよい。
prop_compare :: Int -> Int -> Property
prop_compare x y = (x <= y) .||. (y <= x)

-- conjoin : リストをまとめて「かつ」にする。
--           条件の数が可変のときに使う。
prop_allPrefixesShorter :: [Int] -> Property
prop_allPrefixesShorter xs =
  conjoin [ property (length p <= length xs) | p <- prefixes xs ]
  where prefixes ys = [ take n ys | n <- [0 .. length ys] ]

-- disjoin : リストをまとめて「または」にする。
prop_oneOfThem :: Int -> Property
prop_oneOfThem x = disjoin [ property (x < 0), property (x == 0), property (x > 0) ]

-- わざと失敗させて、どのラベルが出るか確認する
prop_broken :: [Int] -> Property
prop_broken xs =
  counterexample "cond A: always true"   (property True)
    .&&.
  counterexample "cond B: this one is a lie" (property (length xs < 2))

main :: IO ()
main = do
  putStr "sortBasics          : " >> quickCheck prop_sortBasics
  putStr "compare             : " >> quickCheck prop_compare
  putStr "allPrefixesShorter  : " >> quickCheck prop_allPrefixesShorter
  putStr "oneOfThem           : " >> quickCheck prop_oneOfThem
  putStrLn ""
  putStrLn "--- deliberately failing ---"
  quickCheck prop_broken

-- 注意点:
--   * (.&&.) は「両方を評価」します。短絡しません。
--     片方が例外を投げるなら (==>) で先に弾いてください。
--   * 条件が3つ以上になったら、プロパティを分けたほうが読みやすいことが多いです。
--     まとめるのは「同じ入力に対する一連の不変条件」のときだけにしましょう。
--
-- まとめ (Ch1 完了):
--   quickCheck            プロパティを100回試す
--   quickCheckWith Args   件数やサイズを変える
--   verboseCheck          生成値を1件ずつ見る
--   (===) (=/=)           差分が見える比較
--   counterexample        反例に情報を足す
--   (.&&.) (.||.)         条件の合成
--   conjoin disjoin       条件リストの合成
