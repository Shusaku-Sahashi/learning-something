-- Example 62: 数値の Modifier
--
-- QuickCheck には「よくある条件」を表す newtype が用意されています。
-- これを使えば (==>) を書かずに済み、分布も歪みません。
--
-- 実行: runghc Example62.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- Positive a     : 0 より大きい
-- NonNegative a  : 0 以上
-- Negative a     : 0 より小さい
-- NonPositive a  : 0 以下
-- NonZero a      : 0 でない
------------------------------------------------------------

-- Before: 条件で絞る
prop_divBefore :: Int -> Int -> Property
prop_divBefore x y = y /= 0 ==> (x `div` y) * y + (x `mod` y) === x

-- After: Modifier を使う (捨てる入力がゼロになる)
prop_divAfter :: Int -> NonZero Int -> Property
prop_divAfter x (NonZero y) = (x `div` y) * y + (x `mod` y) === x

-- Positive: 「1 以上の個数」など
prop_replicateLength :: Positive Int -> Int -> Property
prop_replicateLength (Positive n) x = length (replicate n x) === n

-- NonNegative: 「0 以上のインデックス」など
prop_takeLength :: NonNegative Int -> [Int] -> Bool
prop_takeLength (NonNegative n) xs = length (take n xs) <= n

-- Negative / NonPositive
prop_negativeAbs :: Negative Int -> Bool
prop_negativeAbs (Negative n) = abs n > 0 || n == minBound

prop_nonPositive :: NonPositive Int -> Bool
prop_nonPositive (NonPositive n) = n <= 0

------------------------------------------------------------
-- Small / Large: 生成される値の大きさを変える
------------------------------------------------------------
-- Small a : 小さい値だけ (サイズパラメータに強く依存)
-- Large a : 型の範囲全体に広がる大きい値も出る
prop_smallValues :: Small Int -> Bool
prop_smallValues (Small n) = abs n <= 1000000

prop_largeValues :: Large Int -> Bool
prop_largeValues (Large n) = n == n

------------------------------------------------------------
-- Modifier は shrink も正しくやってくれる
------------------------------------------------------------
prop_positiveShrink :: Positive Int -> Bool
prop_positiveShrink (Positive n) = n < 50

main :: IO ()
main = do
  putStrLn "--- before / after ---"
  putStr "with (==>)    : " >> quickCheck prop_divBefore
  putStr "with NonZero  : " >> quickCheck prop_divAfter
  putStrLn "  ^ note the discard count disappears"
  putStrLn ""

  putStrLn "--- what each modifier generates ---"
  showSamples "Positive Int   " (arbitrary :: Gen (Positive Int))
  showSamples "NonNegative Int" (arbitrary :: Gen (NonNegative Int))
  showSamples "Negative Int   " (arbitrary :: Gen (Negative Int))
  showSamples "NonPositive Int" (arbitrary :: Gen (NonPositive Int))
  showSamples "NonZero Int    " (arbitrary :: Gen (NonZero Int))
  putStrLn ""

  putStrLn "--- Small vs Large ---"
  smalls <- sequence (replicate 8 (generate (arbitrary :: Gen (Small Int))))
  putStrLn ("  Small: " ++ show [ n | Small n <- smalls ])
  larges <- sequence (replicate 8 (generate (arbitrary :: Gen (Large Int))))
  putStrLn ("  Large: " ++ show [ n | Large n <- larges ])
  putStrLn ""

  putStrLn "--- properties ---"
  putStr "replicate length : " >> quickCheck prop_replicateLength
  putStr "take length      : " >> quickCheck prop_takeLength
  putStr "negative abs     : " >> quickCheck prop_negativeAbs
  putStr "non positive     : " >> quickCheck prop_nonPositive
  putStr "small values     : " >> quickCheck prop_smallValues
  putStr "large values     : " >> quickCheck prop_largeValues
  putStrLn ""

  putStrLn "--- modifiers shrink correctly (stays positive) ---"
  quickCheck prop_positiveShrink
  where
    showSamples label gen = do
      vs <- sequence (replicate 8 (generate gen))
      putStrLn ("  " ++ label ++ ": " ++ show vs)

-- Modifier を使うと何が良いのか:
--   1. 入力が捨てられないので、テスト回数がそのまま有効な試行数になる
--   2. 分布が歪まない
--   3. shrink も不変条件を守ってくれる
--      (Positive 5 を縮小しても Positive 0 や Positive (-1) にはならない)
--   4. 型を見れば前提条件が分かる (ドキュメントとして機能する)
--
-- 迷ったら、まず標準の Modifier で表せないか考えてください。
-- ほとんどの前提条件は、これで書けます。
