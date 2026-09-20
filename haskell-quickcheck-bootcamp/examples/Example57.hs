-- Example 57: 縮小を制御する道具
--
-- 「この値は縮小してほしくない」「表示してほしくない」といった要求に応えます。
--
-- 実行: runghc Example57.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- noShrinking :: Testable prop => prop -> Property
--   そのプロパティ全体で縮小を無効にする。
------------------------------------------------------------
prop_normal :: [Int] -> Bool
prop_normal xs = length xs < 5

------------------------------------------------------------
-- Blind a: 値を表示しない
--   巨大な値や、Show を持たない値を扱うときに使う。
--   Blind は中身を Show しないので、反例に出てきません。
------------------------------------------------------------
prop_blind :: Blind [Int] -> Bool
prop_blind (Blind xs) = length xs < 5

------------------------------------------------------------
-- Fixed a: 縮小しない
--   「この入力は固定して、他の入力だけ縮小したい」ときに使う。
------------------------------------------------------------
prop_fixed :: Fixed [Int] -> [Int] -> Bool
prop_fixed (Fixed xs) ys = length xs + length ys < 8

prop_notFixed :: [Int] -> [Int] -> Bool
prop_notFixed xs ys = length xs + length ys < 8

------------------------------------------------------------
-- Shrink2 a: 2段階まとめて縮小する
--   「1回の縮小の効きが弱い」ときに、縮小を加速する。
------------------------------------------------------------
prop_shrink2 :: Shrink2 Int -> Bool
prop_shrink2 (Shrink2 n) = n < 50

prop_plainInt :: Int -> Bool
prop_plainInt n = n < 50

------------------------------------------------------------
-- shrinking: 特定の値だけ手動で縮小する
--   shrinking :: (a -> [a]) -> a -> (a -> prop) -> Property
------------------------------------------------------------
-- 注意: 外側の forAll が表示する値は縮小されません。
--       縮小されるのは shrinking が包んでいる内側の値です。
--       そのため counterexample で内側の値を出さないと、何が起きたか分かりません。
prop_manualShrinking :: Property
prop_manualShrinking =
  forAllBlind (choose (0, 500 :: Int)) $ \n ->
    shrinking shrink n $ \n' ->
      counterexample ("shrunk value = " ++ show n') (n' < 50)

main :: IO ()
main = do
  putStrLn "--- normal (shrinks) ---"
  quickCheck prop_normal
  putStrLn ""

  putStrLn "--- noShrinking ---"
  quickCheck (noShrinking prop_normal)
  putStrLn ""

  putStrLn "--- Blind (value hidden) ---"
  quickCheck prop_blind
  putStrLn ""

  putStrLn "--- Fixed (first list not shrunk) ---"
  quickCheck prop_fixed
  putStrLn ""

  putStrLn "--- both shrunk, for comparison ---"
  quickCheck prop_notFixed
  putStrLn ""

  putStrLn "--- Shrink2 vs plain Int (count the shrink steps) ---"
  putStr "plain Int : " >> quickCheck prop_plainInt
  putStr "Shrink2   : " >> quickCheck prop_shrink2
  putStrLn ""

  putStrLn "--- shrinking: shrink a value inside forAll ---"
  quickCheck prop_manualShrinking

-- 使い分け:
--
--   noShrinking prop
--     縮小自体が壊れていて固まるとき、緊急避難として。
--     恒久的な解決ではありません。shrink を直してください。
--
--   Blind a
--     * 値が巨大で、画面に出すと読めない
--     * Show インスタンスがない (関数など)
--     ただし反例が何も見えなくなるので、counterexample で要約を出すと良いです。
--
--   Fixed a
--     * 設定値やテーブルなど「縮めても意味がない入力」に付ける
--     * 縮小の探索空間が減るので、縮小が速くなる副次効果もあります
--
--   Shrink2 a
--     * 縮小が遅いとき。1ステップで2段階分進みます。
--
--   shrinking shr x $ \x' -> ...
--     * forAll の中で、特定の値だけ縮小したいとき
--     * forAllShrink で書けるならそちらのほうが読みやすいです
