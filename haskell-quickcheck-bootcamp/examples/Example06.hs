-- Example 06: 型注釈が要る理由
--
-- QuickCheck は「型」を見て入力を生成します。
-- 型が決まらないと生成しようがありません。ここが初学者のつまずきどころです。
--
-- 実行: runghc Example06.hs
{-# LANGUAGE ExtendedDefaultRules #-}
module Main (main) where

import Test.QuickCheck

-- ★ 型注釈なしで書くと何が起きるか
--
-- 次の式は、型としては (Eq a, Arbitrary a, Show a) => [a] -> Bool です。
-- a が何か決まっていません。
--
-- GHC の通常の規則ではこれはコンパイルエラー (曖昧な型変数) になります。
-- しかし GHCi や ExtendedDefaultRules 下では a が () に defaulting されます。
-- () の値は () ただ1つ。つまり「[(),(),()] のようなリストだけ」でテストされ、
-- ほとんど何も検査していないのに 100 tests passed と表示されてしまいます。
--
-- 下の main では、その状況を [()] という型注釈で再現してみせます。

main :: IO ()
main = do
  putStrLn "--- defaulted to () : nothing is really tested ---"
  quickCheck (\xs -> reverse (reverse xs) == (xs :: [()]))
  putStrLn "  ^ passed, but only [(),(),()] was ever tried"
  putStrLn ""

  putStrLn "--- look at what is actually generated ---"
  unitSamples <- sample' (arbitrary :: Gen [()])
  print (take 5 unitSamples)
  intSamples <- sample' (arbitrary :: Gen [Int])
  print (take 5 intSamples)
  putStrLn ""

  putStrLn "--- with an explicit Int annotation ---"
  quickCheck (\xs -> reverse (reverse xs) == (xs :: [Int]))

-- 型を指定する方法は3つあります。どれでも構いません。
--
--   1. トップレベルの型シグネチャ (推奨)
--        prop_rev :: [Int] -> Bool
--        prop_rev xs = reverse (reverse xs) == xs
--
--   2. ラムダの中で注釈
--        quickCheck (\xs -> reverse (reverse xs) == (xs :: [Int]))
--
--   3. quickCheck に渡す式全体へ注釈
--        quickCheck ((\xs -> reverse (reverse xs) == xs) :: [Int] -> Bool)
--
-- 実務では 1 を使ってください。
-- 「テストが一瞬で通るしテスト件数も 100 なのに、バグが見つからない」
-- というときは、まず型が () に落ちていないか疑います。
