-- Example 61: 条件で絞ると分布が歪む
--
-- Gave up にならなくても、(==>) には別の危険があります。
-- 「条件を通った入力」が、想定と全然違う偏り方をすることです。
--
-- 実行: runghc Example61.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 題材: 「2つのリストの長さが等しい」という条件
------------------------------------------------------------
prop_zipSameLength :: [Int] -> [Int] -> Property
prop_zipSameLength xs ys =
  length xs == length ys ==>
    length (zip xs ys) === length xs

-- 条件を通った入力の長さを記録してみます。
-- collect は分布を表示する道具です (Ch7 で詳しく扱います)。
prop_zipDistribution :: [Int] -> [Int] -> Property
prop_zipDistribution xs ys =
  length xs == length ys ==>
    collect (length xs) (length (zip xs ys) == length xs)

------------------------------------------------------------
-- 正しい直し方: 同じ長さのペアを生成する
------------------------------------------------------------
genSameLength :: Gen ([Int], [Int])
genSameLength = do
  n  <- choose (0, 30)
  xs <- vectorOf n arbitrary
  ys <- vectorOf n arbitrary
  pure (xs, ys)

prop_zipFixed :: Property
prop_zipFixed =
  forAll genSameLength $ \(xs, ys) ->
    collect (length xs) (length (zip xs ys) == length xs)

------------------------------------------------------------
-- 題材2: 「偶数」という条件
------------------------------------------------------------
-- 条件で絞る版
prop_evenFiltered :: Int -> Property
prop_evenFiltered n = even n ==> collect (abs n `div` 10) (even (n * 2))

-- 生成する版
prop_evenGenerated :: Property
prop_evenGenerated =
  forAll ((* 2) <$> arbitrary) $ \n ->
    collect (abs (n :: Int) `div` 10) (even (n * 2))

main :: IO ()
main = do
  putStrLn "--- zip with a precondition: works, but look at the lengths ---"
  quickCheck prop_zipSameLength
  putStrLn ""

  putStrLn "--- distribution of lengths that survived the precondition ---"
  quickCheckWith stdArgs { maxSuccess = 200 } prop_zipDistribution
  putStrLn ""

  putStrLn "--- distribution when we generate matching pairs instead ---"
  quickCheckWith stdArgs { maxSuccess = 200 } prop_zipFixed
  putStrLn ""

  putStrLn "--- even, filtered ---"
  quickCheckWith stdArgs { maxSuccess = 200 } prop_evenFiltered
  putStrLn ""

  putStrLn "--- even, generated ---"
  quickCheckWith stdArgs { maxSuccess = 200 } prop_evenGenerated

-- 結果の読み方:
--
--   条件で絞った場合、長さ 0 と 1 が圧倒的に多くなります。
--   「長さが等しい2つのリスト」が偶然できる確率は、
--   短いリストほど高いからです (長さ 0 同士はよく当たる)。
--
--   その結果、長いリストはほとんど試されません。
--   「長いリストでしか出ないバグ」は永遠に見つかりません。
--
--   生成器で作った場合は、長さが 0 から 30 まで均等に出ます。
--
-- 教訓:
--   (==>) は「テストが通ったかどうか」だけ見ていると安全に見えますが、
--   何が試されているかは大きく歪みます。
--   条件を書いたら、必ず collect や classify で分布を確認してください。
--   (Ch7 で本格的に扱います)
