-- Example 35: 不変条件を持つ型を生成する
--
-- 「この型の値は必ずこの条件を満たす」という型を扱うときの定石です。
-- やり方は3つあり、優先順位がはっきりしています。
--
-- 実行: runghc Example35.hs
module Main (main) where

import Data.List (sort, nub)
import Test.QuickCheck

------------------------------------------------------------
-- 題材: 「重複がなく、昇順に並んだ Int のリスト」
------------------------------------------------------------
newtype SortedSet = SortedSet [Int]
  deriving (Show, Eq)

-- 不変条件
validSet :: SortedSet -> Bool
validSet (SortedSet xs) = xs == sort (nub xs)

-- スマートコンストラクタ: どんな入力からでも正しい値を作る
mkSortedSet :: [Int] -> SortedSet
mkSortedSet = SortedSet . sort . nub

insertS :: Int -> SortedSet -> SortedSet
insertS x (SortedSet xs) = mkSortedSet (x : xs)

memberS :: Int -> SortedSet -> Bool
memberS x (SortedSet xs) = x `elem` xs

------------------------------------------------------------
-- 方法1 (最良): スマートコンストラクタを通して生成する
------------------------------------------------------------
genSetViaSmart :: Gen SortedSet
genSetViaSmart = mkSortedSet <$> arbitrary

------------------------------------------------------------
-- 方法2: 構造的に正しいものを直接組み立てる
------------------------------------------------------------
-- 「差分を積み上げる」方法。必ず昇順・重複なしになります。
genSetByDiffs :: Gen SortedSet
genSetByDiffs = do
  start <- arbitrary
  ds    <- listOf (choose (1, 10))        -- 差分は必ず 1 以上
  pure (SortedSet (scanl (+) start ds))

------------------------------------------------------------
-- 方法3 (最後の手段): 生成してから条件で弾く
------------------------------------------------------------
-- 条件を満たす確率が低いので、とても遅くなります。
-- ここでは「遅い」ことを見るために、あえて長さを絞っています。
genSetBySuchThat :: Gen SortedSet
genSetBySuchThat =
  (SortedSet <$> resize 4 (listOf (choose (0, 9)))) `suchThat` validSet

------------------------------------------------------------
-- Arbitrary インスタンスは方法1 を採用
------------------------------------------------------------
instance Arbitrary SortedSet where
  arbitrary = genSetViaSmart

------------------------------------------------------------
-- プロパティ
------------------------------------------------------------
prop_genIsValid1 :: Property
prop_genIsValid1 = forAll genSetViaSmart validSet

prop_genIsValid2 :: Property
prop_genIsValid2 = forAll genSetByDiffs validSet

prop_genIsValid3 :: Property
prop_genIsValid3 = forAll genSetBySuchThat validSet

-- 不変条件は「操作しても保たれる」ことが重要です。
prop_insertKeepsInvariant :: Int -> SortedSet -> Bool
prop_insertKeepsInvariant x s = validSet (insertS x s)

prop_insertThenMember :: Int -> SortedSet -> Bool
prop_insertThenMember x s = memberS x (insertS x s)

prop_insertIdempotent :: Int -> SortedSet -> Property
prop_insertIdempotent x s = insertS x (insertS x s) === insertS x s

main :: IO ()
main = do
  putStrLn "--- method 1: smart constructor ---"
  a <- sample' genSetViaSmart
  mapM_ print (take 5 a)

  putStrLn "--- method 2: build by construction (differences) ---"
  b <- sample' genSetByDiffs
  mapM_ print (take 5 b)

  putStrLn "--- method 3: generate and filter (slow) ---"
  c <- sample' genSetBySuchThat
  mapM_ print (take 5 c)

  putStrLn ""
  putStrLn "--- all three produce valid values ---"
  putStr "method 1 : " >> quickCheck prop_genIsValid1
  putStr "method 2 : " >> quickCheck prop_genIsValid2
  putStr "method 3 : " >> quickCheck prop_genIsValid3

  putStrLn ""
  putStrLn "--- operations preserve the invariant ---"
  putStr "insert valid     : " >> quickCheck prop_insertKeepsInvariant
  putStr "insert then find : " >> quickCheck prop_insertThenMember
  putStr "insert idempotent: " >> quickCheck prop_insertIdempotent

  putStrLn ""
  putStrLn "--- but method 2 has a blind spot: it never makes an empty set ---"
  bs <- sequence (replicate 50 (generate genSetByDiffs))
  putStrLn ("  empty sets out of 50: " ++ show (length (filter (== SortedSet []) bs)))
  as <- sequence (replicate 50 (generate genSetViaSmart))
  putStrLn ("  (method 1)          : " ++ show (length (filter (== SortedSet []) as)))

-- 選び方:
--   1. スマートコンストラクタがあるなら、それを通す。一番簡単で確実。
--   2. なければ、条件を満たすように直接組み立てる。ただし偏りに注意。
--   3. suchThat は最後の手段。遅いうえに偏る。
--
-- 方法2 の落とし穴を見てください。
-- 「差分を積む」実装は空集合を絶対に作りません。
-- 境界値である空集合でのバグを、永遠に見逃すことになります。
-- 自作の生成器は、必ず「作れない値」がないか確認してください。
