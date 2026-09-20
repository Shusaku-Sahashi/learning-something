-- Example 30: 生成器そのものをテストする
--
-- 生成器を自作したら、その生成器が正しいかを確かめてください。
-- 生成器が壊れていると、テストは「通るのにバグを見逃す」状態になります。
-- これは一番たちの悪い失敗です。
--
-- 実行: runghc Example30.hs
module Main (main) where

import Data.List (nub, sort)
import Test.QuickCheck

------------------------------------------------------------
-- 題材: 「有効なメールアドレスっぽい文字列」の生成器
------------------------------------------------------------
genLocal :: Gen String
genLocal = listOf1 (elements (['a' .. 'z'] ++ ['0' .. '9'] ++ "._-"))

genDomain :: Gen String
genDomain = do
  label <- listOf1 (elements (['a' .. 'z'] ++ ['0' .. '9']))
  tld   <- elements ["com", "org", "jp", "dev"]
  return (label ++ "." ++ tld)

genEmail :: Gen String
genEmail = do
  l <- genLocal
  d <- genDomain
  return (l ++ "@" ++ d)

-- 生成器の性質1: 必ず @ をちょうど1つ含む
prop_genEmailHasOneAt :: Property
prop_genEmailHasOneAt =
  forAll genEmail (\e -> length (filter (== '@') e) == 1)

-- 生成器の性質2: 空にならない
prop_genEmailNonEmpty :: Property
prop_genEmailNonEmpty = forAll genEmail (not . null)

-- 生成器の性質3: ドメイン側に . を含む
prop_genEmailHasDot :: Property
prop_genEmailHasDot =
  forAll genEmail (\e -> '.' `elem` drop 1 (dropWhile (/= '@') e))

------------------------------------------------------------
-- 題材: 「ソート済みリスト」の生成器 (よくある間違い付き)
------------------------------------------------------------
-- 正しい版
genSortedGood :: Gen [Int]
genSortedGood = sort <$> arbitrary

-- 間違った版: 「差分を足していく」つもりが、負の差分も足してしまう
genSortedBad :: Gen [Int]
genSortedBad = do
  diffs <- listOf arbitrary
  return (scanl1 (+) diffs)

prop_goodIsSorted :: Property
prop_goodIsSorted = forAll genSortedGood isSortedL

prop_badIsSorted :: Property
prop_badIsSorted = forAll genSortedBad isSortedL

isSortedL :: [Int] -> Bool
isSortedL ys = and (zipWith (<=) ys (drop 1 ys))

------------------------------------------------------------
-- 題材: 「重複のないリスト」の生成器
------------------------------------------------------------
genDistinct :: Gen [Int]
genDistinct = nub <$> arbitrary

prop_distinctIsDistinct :: Property
prop_distinctIsDistinct =
  forAll genDistinct (\xs -> length (nub xs) == length xs)

------------------------------------------------------------
-- 生成器が「十分に多様か」も確かめる
------------------------------------------------------------
-- 「常に空リストを返す生成器」も上のプロパティを全部満たしてしまいます。
genAlwaysEmpty :: Gen [Int]
genAlwaysEmpty = pure []

prop_emptyIsSorted :: Property
prop_emptyIsSorted = forAll genAlwaysEmpty isSortedL

main :: IO ()
main = do
  putStrLn "--- sample emails ---"
  es <- sample' genEmail
  mapM_ putStrLn (take 6 es)
  putStrLn ""

  putStrLn "--- generator properties: email ---"
  putStr "exactly one @   : " >> quickCheck prop_genEmailHasOneAt
  putStr "non-empty       : " >> quickCheck prop_genEmailNonEmpty
  putStr "domain has dot  : " >> quickCheck prop_genEmailHasDot
  putStrLn ""

  putStrLn "--- generator properties: sorted list ---"
  putStr "good generator  : " >> quickCheck prop_goodIsSorted
  putStrLn "bad generator (fails on purpose):"
  quickCheck prop_badIsSorted
  putStrLn ""

  putStrLn "--- distinct generator ---"
  putStr "no duplicates   : " >> quickCheck prop_distinctIsDistinct
  putStrLn ""

  putStrLn "--- a useless generator also passes! ---"
  putStr "always []       : " >> quickCheck prop_emptyIsSorted
  putStrLn "  ^ satisfies the property but tests nothing"
  putStrLn ""
  putStrLn "--- so also look at the values themselves ---"
  ss <- sample' genSortedGood
  print (map length ss)

-- 生成器のチェックリスト:
--   1. 満たすべき不変条件をプロパティで書く (forAll gen (...))
--   2. sample' で実際の値を目で見る
--   3. 長さや値の範囲が偏っていないか確認する
--   4. classify / tabulate で分布を測る (Ch7)
--
-- 「生成器のテスト」は省略されがちですが、
-- 自作の生成器が複雑になるほど重要になります。
