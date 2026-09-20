-- Example 01: はじめてのプロパティ
--
-- QuickCheck の使い方はたった2ステップです。
--   1. 「入力を受け取って True を返す関数」= プロパティ を書く
--   2. quickCheck に渡す
--
-- QuickCheck が入力をランダムに大量生成して、False になるものを探します。
--
-- 実行: runghc Example01.hs
module Main (main) where

import Test.QuickCheck

-- プロパティ: リストを2回ひっくり返すと元に戻る。
-- 引数 xs が「ランダムに生成される入力」です。
-- 型注釈 [Int] は「Int のリストで試せ」という指示です (Example 06 で詳しく扱います)。
prop_reverseTwice :: [Int] -> Bool
prop_reverseTwice xs = reverse (reverse xs) == xs

-- プロパティ: リストを連結しても長さの合計は変わらない。
prop_appendLength :: [Int] -> [Int] -> Bool
prop_appendLength xs ys = length (xs ++ ys) == length xs + length ys

main :: IO ()
main = do
  putStrLn "--- prop_reverseTwice ---"
  quickCheck prop_reverseTwice
  putStrLn "--- prop_appendLength ---"
  quickCheck prop_appendLength

-- 期待される出力:
--   +++ OK, passed 100 tests.
--
-- 「passed 100 tests」は「100個のランダムな入力を試して、すべて True だった」という意味です。
-- 100 という数はデフォルト値で、変更できます (Example 08)。
