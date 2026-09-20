-- Example 26: 自分で Gen を作る (3) リストの生成
--
-- 実行: runghc Example26.hs
module Main (main) where

import Test.QuickCheck

-- listOf :: Gen a -> Gen [a]
--   長さがランダム (サイズに依存) のリスト。0 要素もありえます。
genDiceRolls :: Gen [Int]
genDiceRolls = listOf (choose (1, 6))

-- listOf1 :: Gen a -> Gen [a]
--   長さ 1 以上のリスト。
genNonEmptyRolls :: Gen [Int]
genNonEmptyRolls = listOf1 (choose (1, 6))

-- vectorOf :: Int -> Gen a -> Gen [a]
--   長さちょうど n のリスト。
genFiveRolls :: Gen [Int]
genFiveRolls = vectorOf 5 (choose (1, 6))

-- 長さも指定範囲でランダムにしたい場合
genRollsBetween :: Int -> Int -> Gen [Int]
genRollsBetween lo hi = do
  n <- choose (lo, hi)
  vectorOf n (choose (1, 6))

-- shuffle :: [a] -> Gen [a]
--   与えたリストをランダムに並べ替える。
--   「順列」が欲しいときに便利です。
genPermutationOf1to5 :: Gen [Int]
genPermutationOf1to5 = shuffle [1 .. 5]

-- sublistOf :: [a] -> Gen [a]
--   各要素を 50% の確率で採用した部分リストを作る。順序は保たれます。
genSubsetOf1to10 :: Gen [Int]
genSubsetOf1to10 = sublistOf [1 .. 10]

-- infiniteListOf :: Gen a -> Gen [a]
--   無限リスト。take して使います (Example 67 の InfiniteList も参照)。
genInfiniteRolls :: Gen [Int]
genInfiniteRolls = infiniteListOf (choose (1, 6))

-- growingElements :: [a] -> Gen a
--   サイズが小さいうちはリストの先頭だけから、
--   サイズが大きくなるにつれ後ろの要素も選ばれるようになります。
genGrowing :: Gen Int
genGrowing = growingElements [1 .. 20]

main :: IO ()
main = do
  putStrLn "--- listOf ---"
  a <- sample' genDiceRolls
  mapM_ print (take 6 a)

  putStrLn "--- listOf1 (never empty) ---"
  b <- sample' genNonEmptyRolls
  print (map length (take 8 b))

  putStrLn "--- vectorOf 5 ---"
  c <- sample' genFiveRolls
  mapM_ print (take 4 c)

  putStrLn "--- length between 2 and 4 ---"
  d <- sample' (genRollsBetween 2 4)
  print (map length d)

  putStrLn "--- shuffle [1..5] ---"
  e <- sample' genPermutationOf1to5
  mapM_ print (take 5 e)

  putStrLn "--- sublistOf [1..10] ---"
  f <- sample' genSubsetOf1to10
  mapM_ print (take 5 f)

  putStrLn "--- infiniteListOf (take 10) ---"
  g <- generate genInfiniteRolls
  print (take 10 g)

  putStrLn "--- growingElements [1..20] ---"
  h <- sample' genGrowing
  print h

  putStrLn ""
  putStrLn "--- properties with these generators ---"
  quickCheck (forAll genNonEmptyRolls (not . null))
  quickCheck (forAll genFiveRolls ((== 5) . length))
  quickCheck (forAll genPermutationOf1to5 (\xs -> sum xs == 15))
  quickCheck (forAll genSubsetOf1to10 (all (`elem` [1 .. 10])))

-- 長さの分布に注意:
--   listOf の長さはサイズパラメータに依存します。サイズ 0 なら必ず空です。
--   「長いリストでしか出ないバグ」を探したいときは maxSize を上げるか、
--   vectorOf / choose で明示的に長さを決めてください。
