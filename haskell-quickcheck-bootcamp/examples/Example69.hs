-- Example 69: 前提条件を使ってよい場面
--
-- ここまで「(==>) は避けろ」と言い続けてきましたが、
-- 正当に使える場面もあります。判断基準を整理します。
--
-- 実行: runghc Example69.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 使ってよい場面1: 条件がほぼ常に真 (捨てる数がごく少ない)
------------------------------------------------------------
-- 「ランダムな Int が 0 でない」条件。
-- QuickCheck の Int は小さい値に寄るので 0 もそこそこ出ますが、
-- それでも捨てるのは 1 割前後です。テストとしては十分成立します。
prop_rareDiscard :: Int -> Int -> Property
prop_rareDiscard x y = y /= 0 ==> (x `div` y) * y + (x `mod` y) === x

------------------------------------------------------------
-- 使ってよい場面2: 生成器の中で絞ると、かえって分布が歪む
------------------------------------------------------------
-- 「2つの値が異なる」という条件。
-- 生成器で「異なる2値」を作ろうとすると、
-- 「隣り合った値」ばかりになったりして、かえって偏ることがあります。
-- 素直に生成して、同じだったら捨てるほうが自然です。
prop_distinctPair :: Int -> Int -> Property
prop_distinctPair x y = x /= y ==> (min x y < max x y)

------------------------------------------------------------
-- 使ってよい場面3: 一時的な探索
------------------------------------------------------------
-- 「まず動くテストを書く」段階では (==>) で十分です。
-- 捨てる数を見てから、直すかどうか決めればよい。

------------------------------------------------------------
-- 使ってはいけない場面
------------------------------------------------------------
-- (a) 条件を満たす確率が低い  -> Gave up する (Example 60)
-- (b) 分布が大きく歪む        -> 長い入力が試されない (Example 61)
-- (c) 条件が5つ以上ある       -> 掛け算で確率が落ちる (Example 68)

------------------------------------------------------------
-- 判断のしかた: 捨てる数を測る
------------------------------------------------------------
report :: Testable p => String -> p -> IO ()
report name p = do
  r <- quickCheckWithResult stdArgs { chatty = False, maxSuccess = 500 } p
  putStrLn ("  " ++ pad 24 name ++ describe r)
  where
    pad n s = s ++ replicate (n - length s) ' '
    describe res = case res of
      Success { numTests = n, numDiscarded = d } ->
        let ratio = fromIntegral d / fromIntegral (max 1 (n + d)) :: Double
        in "passed " ++ show n ++ ", discarded " ++ show d
             ++ "  (" ++ show (round (ratio * 100) :: Int) ++ "% wasted)"
             ++ verdict ratio
      GaveUp { numTests = n, numDiscarded = d } ->
        "GAVE UP: only " ++ show n ++ " passed, " ++ show d ++ " discarded  <- rewrite it"
      Failure { numTests = n } -> "FAILED after " ++ show n
      _ -> "?"
    verdict r
      | r < 0.1   = "  -> fine"
      | r < 0.5   = "  -> acceptable, but consider a generator"
      | otherwise = "  -> rewrite the generator"

-- 比較用のプロパティたち
prop_cheap :: Int -> Property
prop_cheap n = n /= 0 ==> n * 2 /= 0

prop_medium :: [Int] -> Property
prop_medium xs = length xs >= 3 ==> length xs >= 3

prop_expensive :: [Int] -> Property
prop_expensive xs = length xs >= 10 ==> length xs >= 10

prop_hopeless :: [Int] -> Property
prop_hopeless xs = sum xs == 100 ==> sum xs == 100

main :: IO ()
main = do
  putStrLn "--- legitimate uses ---"
  putStr "rare discard    : " >> quickCheck prop_rareDiscard
  putStr "distinct pair   : " >> quickCheck prop_distinctPair
  putStrLn ""

  putStrLn "--- measure the waste, then decide ---"
  report "n /= 0" prop_cheap
  report "length >= 3" prop_medium
  report "length >= 10" prop_expensive
  report "sum == 100" prop_hopeless

-- 運用ルールの提案:
--
--   捨てる割合が  10% 未満 -> そのままでよい
--                 10-50%   -> 気になるなら直す。CI が遅いなら直す
--                 50% 超   -> 直す
--                 Gave up  -> 必ず直す
--
-- 「捨てる割合」は quickCheck の出力に必ず表示されます。
--   +++ OK, passed 100 tests; 37 discarded.
-- この "37 discarded" を毎回見る習慣をつけてください。
--
-- 表示されない (discarded が 0) なら、前提条件がないか、
-- すべての入力が条件を満たしているということです。それが理想形です。
