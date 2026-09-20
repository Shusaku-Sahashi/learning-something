-- Example 59: 前提条件 (==>)
--
-- ここから Ch6「入力を絞る」です。
-- 「この条件のときだけ成り立つ」性質を書く方法を学びます。
--
-- 実行: runghc Example59.hs
module Main (main) where

import Test.QuickCheck

-- (==>) :: Testable prop => Bool -> prop -> Property
--   条件が False の入力は「捨てられ」、テスト回数に数えられません。

-- 空リストには head がないので、条件で除外する
prop_headOfSorted :: [Int] -> Property
prop_headOfSorted xs =
  not (null xs) ==> head (mySort xs) === minimum xs

mySort :: [Int] -> [Int]
mySort []     = []
mySort (p:ys) = mySort [ y | y <- ys, y <= p ] ++ [p] ++ mySort [ y | y <- ys, y > p ]

-- ゼロ除算を避ける
prop_divMul :: Int -> Int -> Property
prop_divMul x y = y /= 0 ==> (x `div` y) * y + (x `mod` y) === x

-- 条件を複数つなげる
prop_rangeLength :: Int -> Int -> Property
prop_rangeLength lo hi =
  lo <= hi && hi - lo < 1000 ==> length [lo .. hi] === hi - lo + 1

-- 条件の中で計算した値を使う (let を挟む)
prop_indexInRange :: [Int] -> Int -> Property
prop_indexInRange xs i =
  not (null xs) ==>
    let i' = abs i `mod` length xs
    in (xs !! i') `elem` xs

main :: IO ()
main = do
  putStr "head of sorted  : " >> quickCheck prop_headOfSorted
  putStr "div/mul         : " >> quickCheck prop_divMul
  putStr "range length    : " >> quickCheck prop_rangeLength
  putStr "index in range  : " >> quickCheck prop_indexInRange

  putStrLn ""
  putStrLn "--- what the discard count means ---"
  putStrLn "  '+++ OK, passed 100 tests; 12 discarded.' means:"
  putStrLn "    100 inputs satisfied the precondition and passed"
  putStrLn "     12 inputs did not satisfy it and were thrown away"

-- (==>) の意味:
--   条件 False -> その入力を捨てて、次の入力を生成し直す
--   条件 True  -> 中のプロパティを評価する
--
-- 捨てられた入力は「成功」でも「失敗」でもありません。
-- だから「passed 100 tests」と言われても、実際にはもっと多くの入力が
-- 生成されている可能性があります。
--
-- ★ 重要な注意
--   (==>) は「入力を捨てる」だけで、「条件を満たす入力を作る」わけではありません。
--   条件が厳しいと、いくら生成しても通らず、テストが成立しなくなります。
--   これを次の Example 60 で見ます。
