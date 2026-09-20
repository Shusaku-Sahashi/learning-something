-- Example 65: 自作の Modifier を作る
--
-- 標準の Modifier で足りないときは、自分で作ります。
-- 作り方は「newtype + Arbitrary インスタンス」だけです。
--
-- 実行: runghc Example65.hs
module Main (main) where

import Data.Char (isDigit, isAlpha)
import Data.List (sort, nub)
import Test.QuickCheck

------------------------------------------------------------
-- 作り方1: 制約つきの値
------------------------------------------------------------
-- 「1 以上 100 以下」
newtype Percent = Percent Int
  deriving (Show, Eq)

instance Arbitrary Percent where
  arbitrary = Percent <$> choose (0, 100)
  -- shrink は範囲を守る (Ch5 の教訓)
  shrink (Percent n) = [ Percent n' | n' <- shrink n, n' >= 0, n' <= 100 ]

------------------------------------------------------------
-- 作り方2: 構造に制約がある値
------------------------------------------------------------
-- 「重複がなく、昇順のリスト」
newtype DistinctSorted a = DistinctSorted [a]
  deriving (Show, Eq)

instance (Arbitrary a, Ord a) => Arbitrary (DistinctSorted a) where
  arbitrary = DistinctSorted . sort . nub <$> arbitrary
  shrink (DistinctSorted xs) =
    [ DistinctSorted ys
    | ys <- map (sort . nub) (shrink xs)
    , ys /= xs
    ]

------------------------------------------------------------
-- 作り方3: ドメイン固有の値
------------------------------------------------------------
-- 「有効な識別子」(英字で始まり、英数字が続く)
newtype Identifier = Identifier String
  deriving (Show, Eq)

validIdentifier :: String -> Bool
validIdentifier []       = False
validIdentifier (c : cs) = isAlpha c && all (\x -> isAlpha x || isDigit x) cs

instance Arbitrary Identifier where
  arbitrary = do
    c  <- elements (['a' .. 'z'] ++ ['A' .. 'Z'])
    n  <- choose (0, 10)
    cs <- vectorOf n (elements (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9']))
    pure (Identifier (c : cs))
  -- 文字を削る方向に縮小する。先頭の1文字は必ず残す。
  shrink (Identifier (c : cs)) =
    [ Identifier (c : cs') | cs' <- shrink cs ]
  shrink (Identifier []) = []

------------------------------------------------------------
-- 作り方4: ペアの関係に制約がある値
------------------------------------------------------------
-- 「x <= y であるペア」
data Interval = Interval Int Int
  deriving (Show, Eq)

instance Arbitrary Interval where
  arbitrary = do
    a <- arbitrary
    b <- arbitrary
    pure (Interval (min a b) (max a b))
  shrink (Interval lo hi) =
    [ Interval (min a b) (max a b)
    | (a, b) <- shrink (lo, hi)
    , (min a b, max a b) /= (lo, hi)
    ]

------------------------------------------------------------
-- 作り方5: 既存の Modifier を組み合わせる
------------------------------------------------------------
-- 「空でなく、かつ要素がすべて正」のリスト
newtype PositiveNonEmpty = PositiveNonEmpty [Int]
  deriving (Show, Eq)

instance Arbitrary PositiveNonEmpty where
  arbitrary = do
    NonEmpty xs <- arbitrary
    pure (PositiveNonEmpty (map (getPositive . abs') xs))
    where abs' n = Positive (max 1 (abs n))
  shrink (PositiveNonEmpty xs) =
    [ PositiveNonEmpty ys
    | ys <- shrink xs
    , not (null ys)
    , all (> 0) ys
    ]

------------------------------------------------------------
-- 自作 Modifier のテスト (必ず書く)
------------------------------------------------------------
prop_percentValid :: Percent -> Bool
prop_percentValid (Percent n) = n >= 0 && n <= 100

prop_percentShrinkValid :: Percent -> Bool
prop_percentShrinkValid p = all (\(Percent n) -> n >= 0 && n <= 100) (shrink p)

prop_distinctSortedValid :: DistinctSorted Int -> Bool
prop_distinctSortedValid (DistinctSorted xs) = xs == sort (nub xs)

prop_distinctSortedShrinkValid :: DistinctSorted Int -> Bool
prop_distinctSortedShrinkValid d =
  all (\(DistinctSorted xs) -> xs == sort (nub xs)) (shrink d)

prop_identifierValid :: Identifier -> Bool
prop_identifierValid (Identifier s) = validIdentifier s

prop_identifierShrinkValid :: Identifier -> Bool
prop_identifierShrinkValid i =
  all (\(Identifier s) -> validIdentifier s) (shrink i)

prop_intervalValid :: Interval -> Bool
prop_intervalValid (Interval lo hi) = lo <= hi

prop_intervalShrinkValid :: Interval -> Bool
prop_intervalShrinkValid i = all (\(Interval lo hi) -> lo <= hi) (shrink i)

prop_intervalShrinkNoSelf :: Interval -> Bool
prop_intervalShrinkNoSelf i = i `notElem` shrink i

prop_positiveNonEmptyValid :: PositiveNonEmpty -> Bool
prop_positiveNonEmptyValid (PositiveNonEmpty xs) = not (null xs) && all (> 0) xs

prop_positiveNonEmptyShrinkValid :: PositiveNonEmpty -> Bool
prop_positiveNonEmptyShrinkValid p =
  all (\(PositiveNonEmpty xs) -> not (null xs) && all (> 0) xs) (shrink p)

------------------------------------------------------------
-- 使ってみる
------------------------------------------------------------
prop_intervalContains :: Interval -> Bool
prop_intervalContains (Interval lo hi) = lo `elem` [lo .. hi]

prop_identifierNotNumeric :: Identifier -> Bool
prop_identifierNotNumeric (Identifier s) = not (all isDigit s)

main :: IO ()
main = do
  putStrLn "--- samples ---"
  showSamples "Percent            " (arbitrary :: Gen Percent)
  showSamples "DistinctSorted Int " (arbitrary :: Gen (DistinctSorted Int))
  showSamples "Identifier         " (arbitrary :: Gen Identifier)
  showSamples "Interval           " (arbitrary :: Gen Interval)
  showSamples "PositiveNonEmpty   " (arbitrary :: Gen PositiveNonEmpty)
  putStrLn ""

  putStrLn "--- generators are valid ---"
  putStr "Percent          : " >> quickCheck prop_percentValid
  putStr "DistinctSorted   : " >> quickCheck prop_distinctSortedValid
  putStr "Identifier       : " >> quickCheck prop_identifierValid
  putStr "Interval         : " >> quickCheck prop_intervalValid
  putStr "PositiveNonEmpty : " >> quickCheck prop_positiveNonEmptyValid
  putStrLn ""

  putStrLn "--- shrinks are valid ---"
  putStr "Percent          : " >> quickCheck prop_percentShrinkValid
  putStr "DistinctSorted   : " >> quickCheck prop_distinctSortedShrinkValid
  putStr "Identifier       : " >> quickCheck prop_identifierShrinkValid
  putStr "Interval         : " >> quickCheck prop_intervalShrinkValid
  putStr "Interval no self : " >> quickCheck prop_intervalShrinkNoSelf
  putStr "PositiveNonEmpty : " >> quickCheck prop_positiveNonEmptyShrinkValid
  putStrLn ""

  putStrLn "--- using them ---"
  putStr "interval contains: " >> quickCheck prop_intervalContains
  putStr "id not numeric   : " >> quickCheck prop_identifierNotNumeric
  where
    showSamples label gen = do
      vs <- sequence (replicate 4 (generate gen))
      putStrLn ("  " ++ label ++ ": " ++ show vs)

-- 自作 Modifier のチェックリスト:
--   1. arbitrary が不変条件を守るか
--   2. shrink が不変条件を守るか
--   3. shrink が自分自身を返さないか
--   4. 「作れない値」がないか (境界値に到達できるか)
--
-- 1〜3 はプロパティとして書けます。上のように必ず書いてください。
-- 4 は sample' を目で見るか、Ch7 の classify で測ります。
