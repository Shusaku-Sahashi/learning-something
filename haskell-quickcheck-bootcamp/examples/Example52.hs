-- Example 52: shrink が不変条件を壊す問題
--
-- Ch5 で一番ハマるのがこれです。
-- 「生成器は正しいのに、縮小するとありえない値になる」現象です。
--
-- 実行: runghc Example52.hs
{-# LANGUAGE DeriveGeneric #-}
module Main (main) where

import Data.List (sort, nub)
import GHC.Generics (Generic)
import Test.QuickCheck

------------------------------------------------------------
-- 題材1: lo <= hi という不変条件を持つ範囲型
------------------------------------------------------------
data Range = Range Int Int
  deriving (Show, Eq, Generic)

validRange :: Range -> Bool
validRange (Range lo hi) = lo <= hi

mkRange :: Int -> Int -> Range
mkRange a b = Range (min a b) (max a b)

-- ★ 壊れた実装: genericShrink は lo と hi を独立に縮めるので、
--   lo > hi の値を平気で作ります。
data BadRange = BadRange Int Int
  deriving (Show, Eq, Generic)

instance Arbitrary BadRange where
  -- 生成器は正しい。必ず lo <= hi になります。
  arbitrary = (\a b -> BadRange (min a b) (max a b))
                <$> choose (0, 100) <*> choose (0, 100)
  shrink = genericShrink

validBadRange :: BadRange -> Bool
validBadRange (BadRange lo hi) = lo <= hi

-- 修正版1: 縮小後に不変条件で絞る
instance Arbitrary Range where
  arbitrary = mkRange <$> choose (0, 100) <*> choose (0, 100)
  shrink (Range lo hi) =
    [ r | r <- genericShrink (Range lo hi), validRange r ]

-- 修正版2: 縮小後にスマートコンストラクタを通して直す
newtype Range2 = Range2 Range
  deriving (Show, Eq)

instance Arbitrary Range2 where
  arbitrary = Range2 <$> arbitrary
  shrink (Range2 (Range lo hi)) =
    [ Range2 (mkRange lo' hi') | (lo', hi') <- shrink (lo, hi) ]

------------------------------------------------------------
-- 題材2: ソート済みリスト
------------------------------------------------------------
newtype SortedInts = SortedInts [Int]
  deriving (Show, Eq)

isSortedL :: [Int] -> Bool
isSortedL xs = and (zipWith (<=) xs (drop 1 xs))

-- ★ 壊れた実装: 要素を独立に縮めると順序が崩れます。
newtype BadSorted = BadSorted [Int]
  deriving (Show, Eq)

instance Arbitrary BadSorted where
  arbitrary = BadSorted . sort <$> arbitrary
  shrink (BadSorted xs) = [ BadSorted ys | ys <- shrink xs ]

-- 修正版: 縮小後に sort し直す (重複も除く)
instance Arbitrary SortedInts where
  arbitrary = SortedInts . sort . nub <$> arbitrary
  shrink (SortedInts xs) =
    [ SortedInts (sort (nub ys)) | ys <- shrink xs ]

------------------------------------------------------------
-- プロパティ
------------------------------------------------------------
-- 「生成器と縮小が不変条件を守っているか」を直接テストします。
-- これが Ch5 で一番重要なプロパティです。
prop_badRangeShrinkValid :: BadRange -> Property
prop_badRangeShrinkValid r =
  counterexample (show (take 5 (shrink r)))
    (all validBadRange (shrink r))

prop_rangeShrinkValid :: Range -> Bool
prop_rangeShrinkValid r = all validRange (shrink r)

prop_range2ShrinkValid :: Range2 -> Bool
prop_range2ShrinkValid r = all (\(Range2 x) -> validRange x) (shrink r)

prop_badSortedShrinkValid :: BadSorted -> Property
prop_badSortedShrinkValid s@(BadSorted _) =
  counterexample (show (take 5 (shrink s)))
    (all (\(BadSorted ys) -> isSortedL ys) (shrink s))

prop_sortedShrinkValid :: SortedInts -> Bool
prop_sortedShrinkValid s = all (\(SortedInts ys) -> isSortedL ys) (shrink s)

------------------------------------------------------------
-- 「壊れた縮小」が引き起こす実害
------------------------------------------------------------
-- lo <= hi を前提にしている関数。範囲が逆だと空リストになり、!! が落ちます。
midpoint :: Int -> Int -> Int
midpoint lo hi = [lo .. hi] !! ((hi - lo) `div` 2)

-- 縮小候補の中に「不正な範囲」が混ざっていることを、目で確かめます。
badCandidates :: [BadRange]
badCandidates = [ r | r <- shrink (BadRange 7 7), not (validBadRange r) ]

goodCandidates :: [Range]
goodCandidates = [ r | r <- shrink (Range 7 7), not (validRange r) ]

main :: IO ()
main = do
  putStrLn "--- BadRange: genericShrink breaks the invariant ---"
  putStrLn ("  shrink (BadRange 2 5) = " ++ show (shrink (BadRange 2 5)))
  putStrLn "  ^ BadRange 2 0 has lo > hi. The invariant is already broken."
  quickCheck prop_badRangeShrinkValid
  putStrLn ""

  putStrLn "--- Range: filtered shrink keeps the invariant ---"
  putStrLn ("  shrink (Range 2 5) = " ++ show (shrink (Range 2 5)))
  putStr "  " >> quickCheck prop_rangeShrinkValid
  putStrLn ""

  putStrLn "--- Range2: repaired shrink keeps the invariant ---"
  putStrLn ("  shrink (Range2 (Range 2 5)) = " ++ show (shrink (Range2 (Range 2 5))))
  putStr "  " >> quickCheck prop_range2ShrinkValid
  putStrLn ""

  putStrLn "--- BadSorted: element-wise shrink breaks sortedness ---"
  putStrLn ("  shrink (BadSorted [1,2,3]) = " ++ show (take 6 (shrink (BadSorted [1, 2, 3]))))
  quickCheck prop_badSortedShrinkValid
  putStrLn ""

  putStrLn "--- SortedInts: re-sorted shrink is fine ---"
  putStrLn ("  shrink (SortedInts [1,2,3]) = " ++ show (take 6 (shrink (SortedInts [1, 2, 3]))))
  putStr "  " >> quickCheck prop_sortedShrinkValid
  putStrLn ""

  putStrLn "--- the real damage ---"
  putStrLn ("  invalid candidates in shrink (BadRange 7 7): " ++ show badCandidates)
  putStrLn ("  invalid candidates in shrink (Range 7 7)   : " ++ show goodCandidates)
  putStrLn ""
  putStrLn "  midpoint assumes lo <= hi. On a valid range it works:"
  putStrLn ("    midpoint 7 9 = " ++ show (midpoint 7 9))
  putStrLn "  On the invalid candidate above it throws:"
  r <- quickCheckResult (once (total (midpoint 7 0)))
  putStrLn ("  (isSuccess = " ++ show (isSuccess r) ++ ")")
  putStrLn ""
  putStrLn "  If QuickCheck walks into that candidate while shrinking, it reports"
  putStrLn "  an exception for an input your code can never actually receive."
  putStrLn "  You then spend an hour debugging a bug that does not exist."

-- 教訓:
--   不変条件を持つ型の shrink は、必ず次のどちらかにしてください。
--
--     (a) 縮小候補を不変条件で filter する
--           shrink x = [ y | y <- genericShrink x, valid y ]
--
--     (b) 縮小候補をスマートコンストラクタで直す
--           shrink (N a b) = [ mkN a' b' | (a',b') <- shrink (a,b) ]
--
--   (a) は候補が減るので縮小が弱くなることがあります。
--   (b) は候補が増えますが、「同じ値」が混ざると無限ループの危険があります
--       (Example 53)。
--
--   そして必ず、次のプロパティを書いてください。
--
--     prop_shrinkPreservesInvariant :: MyType -> Bool
--     prop_shrinkPreservesInvariant x = all valid (shrink x)
--
--   これを書いておけば、この種のバグは自動で見つかります。
