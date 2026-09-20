-- Example 44: forAll とその仲間
--
-- Arbitrary インスタンスを使わず、その場限りの生成器でテストしたいときに使います。
--
-- 実行: runghc Example44.hs
module Main (main) where

import Data.List (sort)
import Test.QuickCheck

------------------------------------------------------------
-- forAll :: (Show a, Testable prop) => Gen a -> (a -> prop) -> Property
------------------------------------------------------------
-- 一番よく使う形。ただし shrink されません。
prop_forAll :: Property
prop_forAll =
  forAll (listOf (choose (0, 100 :: Int))) (\xs -> length xs < 20)

------------------------------------------------------------
-- forAllShrink :: Gen a -> (a -> [a]) -> (a -> prop) -> Property
------------------------------------------------------------
-- 縮小関数も一緒に渡します。反例が小さくなるので、こちらを推奨します。
prop_forAllShrink :: Property
prop_forAllShrink =
  forAllShrink (listOf (choose (0, 100 :: Int))) shrink (\xs -> length xs < 20)

-- 縮小関数が生成器の不変条件を壊さないように注意 (Ch5 で詳しく)。
-- ソート済みリストを生成しているなら、縮小後もソート済みであるべきです。
genSorted :: Gen [Int]
genSorted = sort <$> arbitrary

shrinkSorted :: [Int] -> [[Int]]
shrinkSorted xs = [ sort ys | ys <- shrink xs ]

prop_sortedShrink :: Property
prop_sortedShrink =
  forAllShrink genSorted shrinkSorted (\xs -> sum xs < 100)

------------------------------------------------------------
-- forAllBlind :: Gen a -> (a -> prop) -> Property
------------------------------------------------------------
-- 生成した値を表示しません。Show インスタンスがない型に使えます。
-- 反例が出ても中身が見えないので、使いどころは限られます。
prop_forAllBlind :: Property
prop_forAllBlind =
  forAllBlind (arbitrary :: Gen (Int -> Int)) (\f -> f 0 == f 0)

------------------------------------------------------------
-- forAllShow :: Gen a -> (a -> String) -> (a -> prop) -> Property
------------------------------------------------------------
-- 表示方法を自分で指定します。
-- 巨大な値を要約して出したいときや、Show がない型を表示したいときに便利です。
data Matrix = Matrix [[Int]]

renderMatrix :: Matrix -> String
renderMatrix (Matrix rows) =
  "Matrix " ++ show (length rows) ++ "x" ++ show (length (head (rows ++ [[]])))
    ++ " " ++ show (take 2 rows) ++ "..."

genMatrix :: Gen Matrix
genMatrix = do
  n <- choose (1, 4)
  m <- choose (1, 4)
  Matrix <$> vectorOf n (vectorOf m (choose (0, 9)))

prop_forAllShow :: Property
prop_forAllShow =
  forAllShow genMatrix renderMatrix
    (\(Matrix rows) -> all (\r -> length r == length (head rows)) rows)

-- わざと失敗させて、表示のされ方を見る
prop_forAllShowFails :: Property
prop_forAllShowFails =
  forAllShow genMatrix renderMatrix
    (\(Matrix rows) -> length rows == 1)

------------------------------------------------------------
-- 組み合わせる: forAll は入れ子にできる
------------------------------------------------------------
prop_nested :: Property
prop_nested =
  forAll (choose (1, 10 :: Int)) $ \n ->
    forAll (vectorOf n (choose (0, 9 :: Int))) $ \xs ->
      length xs === n

main :: IO ()
main = do
  putStrLn "--- forAll (no shrinking) ---"
  quickCheck prop_forAll
  putStrLn ""

  putStrLn "--- forAllShrink (shrinks, much smaller counterexample) ---"
  quickCheck prop_forAllShrink
  putStrLn ""

  putStrLn "--- forAllShrink with an invariant-preserving shrink ---"
  quickCheck prop_sortedShrink
  putStrLn ""

  putStrLn "--- forAllBlind (value is not shown) ---"
  quickCheck prop_forAllBlind
  putStrLn ""

  putStrLn "--- forAllShow (custom rendering) ---"
  quickCheck prop_forAllShow
  putStrLn "forAllShow, failing on purpose:"
  quickCheck prop_forAllShowFails
  putStrLn ""

  putStrLn "--- nested forAll ---"
  quickCheck prop_nested

-- 上の forAll と forAllShrink の反例を見比べてください。
-- forAll のほうは「長さ 20 のごちゃごちゃしたリスト」、
-- forAllShrink のほうは「[0,0,...,0] のような最小のリスト」になります。
--
-- 使い分け:
--   forAllShrink  基本これ。生成器と縮小をその場で指定する。
--   forAll        縮小が不要なとき、または shrink が面倒なとき。
--   forAllBlind   Show がない型 (関数など)。
--   forAllShow    表示を自分で制御したいとき。
--
-- なお、型に Arbitrary インスタンスを書いておけば
-- (shrink も含めて) quickCheck が自動で両方使ってくれます。
-- 次の Example 45 で、どちらを選ぶかの判断基準を扱います。
