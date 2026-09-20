-- Example 63: リストと文字列の Modifier
--
-- 実行: runghc Example63.hs
module Main (main) where

import Data.Char (isAscii, isPrint)
import Data.List (sort)
import Test.QuickCheck

------------------------------------------------------------
-- NonEmptyList a  (コンストラクタは NonEmpty)
--   空でないリスト
------------------------------------------------------------
-- Before
prop_headBefore :: [Int] -> Property
prop_headBefore xs = not (null xs) ==> head xs `elem` xs

-- After
prop_headAfter :: NonEmptyList Int -> Bool
prop_headAfter (NonEmpty xs) = head xs `elem` xs

prop_lastAfter :: NonEmptyList Int -> Bool
prop_lastAfter (NonEmpty xs) = last xs `elem` xs

prop_minMax :: NonEmptyList Int -> Bool
prop_minMax (NonEmpty xs) = minimum xs <= maximum xs

------------------------------------------------------------
-- OrderedList a  (コンストラクタは Ordered)
--   昇順に並んだリスト
------------------------------------------------------------
prop_orderedIsSorted :: OrderedList Int -> Bool
prop_orderedIsSorted (Ordered xs) = xs == sort xs

-- 二分探索のように「ソート済みを前提にする関数」のテストに使えます。
binarySearch :: Int -> [Int] -> Bool
binarySearch _ [] = False
binarySearch t xs =
  let n = length xs
      m = n `div` 2
      v = xs !! m
  in case compare t v of
       EQ -> True
       LT -> binarySearch t (take m xs)
       GT -> binarySearch t (drop (m + 1) xs)

prop_binarySearchFinds :: OrderedList Int -> Property
prop_binarySearchFinds (Ordered xs) =
  not (null xs) ==>
    forAll (elements xs) (`binarySearch` xs)

prop_binarySearchMatchesElem :: OrderedList Int -> Int -> Property
prop_binarySearchMatchesElem (Ordered xs) t =
  binarySearch t xs === (t `elem` xs)

------------------------------------------------------------
-- SortedList a  (コンストラクタは Sorted)
--   OrderedList とほぼ同じ役割
------------------------------------------------------------
prop_sortedIsSorted :: SortedList Int -> Bool
prop_sortedIsSorted (Sorted xs) = xs == sort xs

------------------------------------------------------------
-- InfiniteList a
--   無限リスト。take して使う。Show は「使った分だけ」表示される。
------------------------------------------------------------
prop_takeFromInfinite :: NonNegative Int -> InfiniteList Int -> Bool
prop_takeFromInfinite (NonNegative n) (InfiniteList xs _) =
  length (take (n `mod` 100) xs) == n `mod` 100

------------------------------------------------------------
-- 文字列の Modifier
--   ASCIIString    : ASCII 文字だけ
--   PrintableString: 表示可能な文字だけ
--   UnicodeString  : Unicode 全域 (絵文字や制御文字も混ざる)
------------------------------------------------------------
prop_asciiIsAscii :: ASCIIString -> Bool
prop_asciiIsAscii (ASCIIString s) = all isAscii s

prop_printableIsPrintable :: PrintableString -> Bool
prop_printableIsPrintable (PrintableString s) = all isPrint s

prop_unicodeRoundTrip :: UnicodeString -> Property
prop_unicodeRoundTrip (UnicodeString s) = read (show s) === s

main :: IO ()
main = do
  putStrLn "--- NonEmptyList ---"
  putStr "before (==>)   : " >> quickCheck prop_headBefore
  putStr "after NonEmpty : " >> quickCheck prop_headAfter
  putStr "last           : " >> quickCheck prop_lastAfter
  putStr "min <= max     : " >> quickCheck prop_minMax
  putStrLn ""

  putStrLn "--- OrderedList / SortedList ---"
  os <- sample' (arbitrary :: Gen (OrderedList Int))
  print (take 4 os)
  putStr "is sorted            : " >> quickCheck prop_orderedIsSorted
  putStr "sorted is sorted     : " >> quickCheck prop_sortedIsSorted
  putStr "binary search finds  : " >> quickCheck prop_binarySearchFinds
  putStr "matches elem         : " >> quickCheck prop_binarySearchMatchesElem
  putStrLn ""

  putStrLn "--- InfiniteList ---"
  putStr "take works           : " >> quickCheck prop_takeFromInfinite
  putStrLn ""

  putStrLn "--- string modifiers ---"
  as <- sample' (arbitrary :: Gen ASCIIString)
  putStrLn ("  ASCII    : " ++ show (take 4 [ s | ASCIIString s <- as ]))
  ps <- sample' (arbitrary :: Gen PrintableString)
  putStrLn ("  Printable: " ++ show (take 4 [ s | PrintableString s <- ps ]))
  us <- sample' (arbitrary :: Gen UnicodeString)
  putStrLn ("  Unicode  : " ++ show (take 4 [ s | UnicodeString s <- us ]))
  putStrLn ""
  putStr "ascii is ascii       : " >> quickCheck prop_asciiIsAscii
  putStr "printable is print   : " >> quickCheck prop_printableIsPrintable
  putStr "unicode round trip   : " >> quickCheck prop_unicodeRoundTrip

-- 文字列 Modifier の使い分け:
--
--   ASCIIString     ASCII しか受け付けない仕様のとき
--   PrintableString ログ出力や画面表示のテスト (制御文字が邪魔なとき)
--   UnicodeString   国際化のテスト。絵文字や結合文字でのバグを探せる
--   String (素)     デフォルト。Unicode も含むが、分布は実装依存
--
-- 実務では「素の String でテストしたら制御文字で落ちた」
-- というのはよくある話です。
-- 本番で ASCII しか来ないなら ASCIIString を、
-- 何でも来るなら UnicodeString を使って、意図を明示してください。
