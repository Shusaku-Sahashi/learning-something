-- Example 02: 失敗するプロパティと反例の読み方
--
-- QuickCheck の本当の価値は「失敗したとき」に出ます。
-- 単に「落ちた」と言うだけでなく、できるだけ小さい反例を見せてくれます。
--
-- 実行: runghc Example02.hs
module Main (main) where

import Test.QuickCheck

-- わざと間違ったプロパティ: 「リストをひっくり返しても元と同じ」
-- 当然これは嘘です。
prop_wrong :: [Int] -> Bool
prop_wrong xs = reverse xs == xs

-- こちらもわざと間違い: 「引き算は交換法則を満たす」
prop_subCommutes :: Int -> Int -> Bool
prop_subCommutes x y = x - y == y - x

main :: IO ()
main = do
  putStrLn "--- prop_wrong (this FAILS on purpose) ---"
  quickCheck prop_wrong
  putStrLn ""
  putStrLn "--- prop_subCommutes (this FAILS on purpose) ---"
  quickCheck prop_subCommutes

-- 出力の読み方:
--
--   *** Failed! Falsified (after 6 tests and 5 shrinks):
--   [0,1]
--
--   after 6 tests  : 6個目の入力で初めて False になった
--   and 5 shrinks  : そこから5回「縮小」して、もっと小さい反例にたどり着いた
--   [0,1]          : 最終的な反例。これが prop_wrong を False にする入力
--
-- 最初に見つかった反例は [3,-7,0,12,-2] のようなゴミ混じりの値ですが、
-- QuickCheck は自動でそれを削って [0,1] という「本質だけ残した」反例にします。
-- この「縮小 (shrinking)」が QuickCheck の生命線です (Ch5 で詳しく扱います)。
--
-- prop_subCommutes の反例は 0 と 1 のような最小の組になります。
