-- Example 47: shrink がないとどうなるか
--
-- ここから Ch5「縮小 (shrinking)」です。
-- まず「shrink がない世界」を体験して、ありがたみを理解します。
--
-- 実行: runghc Example47.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 題材: バグのある「リストの最大値」
------------------------------------------------------------
-- 「最初の要素が最大値だと思い込む」バグ
maxBuggy :: [Int] -> Int
maxBuggy []     = minBound
maxBuggy (x:xs) = if x > 0 then x else maximum (x : xs)

------------------------------------------------------------
-- 縮小するリスト型 (標準の [Int] を使う)
------------------------------------------------------------
prop_withShrink :: [Int] -> Property
prop_withShrink xs =
  not (null xs) ==> maxBuggy xs === maximum xs

------------------------------------------------------------
-- 縮小しないリスト型
------------------------------------------------------------
newtype NoShrinkList = NoShrinkList [Int]
  deriving (Show)

instance Arbitrary NoShrinkList where
  arbitrary = NoShrinkList <$> arbitrary
  -- shrink を定義しない = デフォルトの「縮小候補なし」になる
  -- (Arbitrary クラスの shrink のデフォルト実装は  shrink _ = []  です)

prop_withoutShrink :: NoShrinkList -> Property
prop_withoutShrink (NoShrinkList xs) =
  not (null xs) ==> maxBuggy xs === maximum xs

main :: IO ()
main = do
  putStrLn "--- WITHOUT shrinking ---"
  quickCheck prop_withoutShrink
  putStrLn ""
  putStrLn "--- WITH shrinking (default [Int] instance) ---"
  quickCheck prop_withShrink
  putStrLn ""
  putStrLn "--- the bug, stated plainly ---"
  putStrLn ("  maxBuggy [1,5] = " ++ show (maxBuggy [1, 5]))
  putStrLn ("  maximum  [1,5] = " ++ show (maximum [1, 5 :: Int]))

-- 見比べてください。
--
-- shrink なし:
--   *** Failed! Falsified (after 5 tests):
--   NoShrinkList [3,-1,8,-4,6,2]
--   3 /= 8
--     -> どの要素が原因か分からない。6要素のどれを消せばいいのか。
--
-- shrink あり:
--   *** Failed! Falsified (after 5 tests and 4 shrinks):
--   [1,2]
--   1 /= 2
--     -> 「正の数が先頭にあって、後ろにもっと大きい数がある」
--        という条件が一目で分かる。
--
-- shrink は「バグの本質だけを残す」作業です。
-- 実務では、生の反例は数十要素のリストや深くネストした JSON になります。
-- 縮小がないと、そこから原因を読み取るのは現実的ではありません。
--
-- 結論: 自作型に Arbitrary を書いたら、shrink も書いてください。
--       次の Example から、その書き方を学びます。
