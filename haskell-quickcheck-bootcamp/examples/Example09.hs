-- Example 09: counterexample で反例に情報を足す
--
-- 反例に「入力」だけでなく「途中の計算結果」も表示させると、
-- 原因の特定が一気に速くなります。
--
-- 実行: runghc Example09.hs
module Main (main) where

import Data.List (sort)
import Test.QuickCheck

-- テスト対象: 中央値を求める (わざとバグ入り)
median :: [Int] -> Int
median xs = sort xs !! (length xs `div` 2 - 1)   -- ★ -1 が余計

prop_medianInRange :: [Int] -> Property
prop_medianInRange xs =
  not (null xs) ==>           -- 空リストは除外 (Ch6 で詳しく)
    let s = sort xs
        m = median xs
    -- counterexample は「失敗したときだけ」表示される文字列を足します。
    in counterexample ("sorted = " ++ show s) $
       counterexample ("median = " ++ show m) $
         m >= head s && m <= last s

-- counterexample を使わない版と比べてみてください。
prop_medianPlain :: [Int] -> Property
prop_medianPlain xs =
  not (null xs) ==>
    let s = sort xs
        m = median xs
    in m >= head s && m <= last s

main :: IO ()
main = do
  putStrLn "--- without counterexample ---"
  quickCheck prop_medianPlain
  putStrLn ""
  putStrLn "--- with counterexample ---"
  quickCheck prop_medianInRange

-- counterexample あり版の出力例:
--
--   *** Failed! Exception: 'Prelude.!!: negative index' (after 1 test):
--   [0]
--   median = ...
--   sorted = [0]
--
-- 「入力は [0]、ソート結果は [0]、そこで median の計算が落ちた」
-- と分かるので、!! のインデックス計算が怪しいとすぐ当たりがつきます。
--
-- 補足:
--   counterexample は右結合で重ねられます。
--   表示順は「内側に書いたものが先」になります。
--   (?) という中置演算子でも同じことができます:  ("info" ?) $ prop
