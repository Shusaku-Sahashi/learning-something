-- Example 05: (===) を使うと「何と何が違ったか」が見える
--
-- (==) で比較すると、失敗しても「入力」しか表示されません。
-- (===) を使うと「左辺の値 /= 右辺の値」まで表示してくれます。
--
-- 実行: runghc Example05.hs
module Main (main) where

import Test.QuickCheck

-- テスト対象: リストの末尾に要素を足す (わざとバグ入り)
snocBuggy :: a -> [a] -> [a]
snocBuggy x xs = x : xs   -- ★本当は xs ++ [x] にすべき

-- (==) 版: Bool を返す
prop_withEq :: Int -> [Int] -> Bool
prop_withEq x xs = snocBuggy x xs == xs ++ [x]

-- (===) 版: Property を返す
prop_withTripleEq :: Int -> [Int] -> Property
prop_withTripleEq x xs = snocBuggy x xs === xs ++ [x]

main :: IO ()
main = do
  putStrLn "--- using (==) ---"
  quickCheck prop_withEq
  putStrLn ""
  putStrLn "--- using (===) ---"
  quickCheck prop_withTripleEq

-- 出力の違い:
--
--   (==) の場合:
--     *** Failed! Falsified (after 2 tests):
--     0
--     [1]
--     -> 入力が 0 と [1] だったことしか分からない
--
--   (===) の場合:
--     *** Failed! Falsified (after 2 tests):
--     0
--     [1]
--     [0,1] /= [1,0]
--     -> 「[0,1] が返ったが [1,0] を期待していた」と分かる
--
-- 原則: 等価性を確かめるプロパティでは (==) ではなく (===) を使う。
-- タイプ数は1文字増えるだけで、デバッグ時間は大きく減ります。
--
-- 関連する演算子:
--   (=/=)   : 等しくないことを表明する
--   (==>)   : 前提条件 (Ch6)
