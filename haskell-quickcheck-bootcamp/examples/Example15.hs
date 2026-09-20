-- Example 15: パターン4「代数法則 (結合律・交換律・単位元)」
--
-- 数学の法則をそのままプロパティにします。
-- 自作のデータ型に Semigroup / Monoid のインスタンスを書いたら、
-- 必ずこの3つを確認してください。
--
-- 実行: runghc Example15.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 既存の演算で法則を確かめる
------------------------------------------------------------
prop_appendAssoc :: [Int] -> [Int] -> [Int] -> Property
prop_appendAssoc xs ys zs = (xs ++ ys) ++ zs === xs ++ (ys ++ zs)

prop_appendLeftUnit :: [Int] -> Property
prop_appendLeftUnit xs = [] ++ xs === xs

prop_appendRightUnit :: [Int] -> Property
prop_appendRightUnit xs = xs ++ [] === xs

-- (++) は交換律を満たしません。わざと確かめます。
prop_appendCommutes :: [Int] -> [Int] -> Property
prop_appendCommutes xs ys = xs ++ ys === ys ++ xs

prop_maxAssoc :: Int -> Int -> Int -> Property
prop_maxAssoc x y z = max (max x y) z === max x (max y z)

prop_maxCommutes :: Int -> Int -> Property
prop_maxCommutes x y = max x y === max y x

------------------------------------------------------------
-- 自作 Monoid の法則を確かめる
------------------------------------------------------------
-- 「最小値と最大値を同時に覚える」型
data MinMax = MinMax Int Int | Empty
  deriving (Eq, Show)

instance Semigroup MinMax where
  Empty <> a = a
  a <> Empty = a
  MinMax lo1 hi1 <> MinMax lo2 hi2 = MinMax (min lo1 lo2) (max hi1 hi2)

instance Monoid MinMax where
  mempty = Empty

instance Arbitrary MinMax where
  arbitrary = frequency
    [ (1, pure Empty)
    , (4, do a <- arbitrary
             b <- arbitrary
             pure (MinMax (min a b) (max a b)))
    ]

prop_minMaxAssoc :: MinMax -> MinMax -> MinMax -> Property
prop_minMaxAssoc a b c = (a <> b) <> c === a <> (b <> c)

prop_minMaxLeftUnit :: MinMax -> Property
prop_minMaxLeftUnit a = mempty <> a === a

prop_minMaxRightUnit :: MinMax -> Property
prop_minMaxRightUnit a = a <> mempty === a

prop_minMaxCommutes :: MinMax -> MinMax -> Property
prop_minMaxCommutes a b = a <> b === b <> a

main :: IO ()
main = do
  putStrLn "--- (++) ---"
  putStr "associative      : " >> quickCheck prop_appendAssoc
  putStr "left  identity   : " >> quickCheck prop_appendLeftUnit
  putStr "right identity   : " >> quickCheck prop_appendRightUnit
  putStrLn "commutative (expected to FAIL):"
  quickCheck prop_appendCommutes
  putStrLn ""
  putStrLn "--- max ---"
  putStr "associative      : " >> quickCheck prop_maxAssoc
  putStr "commutative      : " >> quickCheck prop_maxCommutes
  putStrLn ""
  putStrLn "--- MinMax (own Monoid) ---"
  putStr "associative      : " >> quickCheck prop_minMaxAssoc
  putStr "left  identity   : " >> quickCheck prop_minMaxLeftUnit
  putStr "right identity   : " >> quickCheck prop_minMaxRightUnit
  putStr "commutative      : " >> quickCheck prop_minMaxCommutes

-- 型クラスの法則はプロパティテストの最高の題材です。
-- チェックリスト:
--   Semigroup : 結合律
--   Monoid    : 左単位元・右単位元
--   Functor   : fmap id == id,  fmap (f . g) == fmap f . fmap g
--   Applicative / Monad : 単位元律・結合律
--   Ord       : 全順序 (反射・反対称・推移・全域)
--   Eq        : 反射・対称・推移
-- (Functor 則などは関数を生成する必要があります。Example 45 で扱います)
