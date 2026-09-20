-- Example 48: shrink の契約と、デフォルト実装の挙動
--
-- shrink :: a -> [a]
--   「この値より小さい候補たち」を返す関数です。
--
-- 守るべき契約は2つだけです。
--   1. 返す値は、元の値より「厳密に小さい」こと
--      (そうでないと縮小が無限ループします)
--   2. 有限のリストを返すこと
--
-- 実行: runghc Example48.hs
module Main (main) where

import Test.QuickCheck

main :: IO ()
main = do
  putStrLn "--- shrink on Int ---"
  mapM_ showShrinkInt [0, 1, 2, 3, 10, 100, -7]
  putStrLn ""

  putStrLn "--- shrink on Bool / Char ---"
  putStrLn ("  shrink True  = " ++ show (shrink True))
  putStrLn ("  shrink False = " ++ show (shrink False))
  putStrLn ("  shrink 'z'   = " ++ show (shrink 'z'))
  putStrLn ("  shrink 'a'   = " ++ show (shrink 'a'))
  putStrLn ""

  putStrLn "--- shrink on lists ---"
  putStrLn ("  shrink [1,2,3] = " ++ show (shrink [1, 2, 3 :: Int]))
  putStrLn ("  shrink [1]     = " ++ show (shrink [1 :: Int]))
  putStrLn ("  shrink []      = " ++ show (shrink ([] :: [Int])))
  putStrLn ""

  putStrLn "--- shrink on tuples ---"
  putStrLn ("  shrink (1,2)   = " ++ show (shrink (1 :: Int, 2 :: Int)))
  putStrLn ""

  putStrLn "--- shrink on Maybe / Either ---"
  putStrLn ("  shrink (Just 3)      = " ++ show (shrink (Just (3 :: Int))))
  putStrLn ("  shrink (Nothing::Maybe Int) = " ++ show (shrink (Nothing :: Maybe Int)))
  putStrLn ("  shrink (Left 5 :: Either Int Bool) = "
              ++ show (shrink (Left 5 :: Either Int Bool)))
  putStrLn ""

  putStrLn "--- shrink on String ---"
  putStrLn ("  shrink \"abc\" = " ++ show (take 8 (shrink "abc")))
  putStrLn ""

  putStrLn "--- the shrink contract, checked ---"
  putStr "int shrinks are smaller  : " >> quickCheck prop_intShrinkSmaller
  putStr "list shrinks are smaller : " >> quickCheck prop_listShrinkSmaller
  putStr "shrink is finite         : " >> quickCheck prop_shrinkFinite
  putStr "shrink [] is []          : " >> quickCheck prop_shrinkEmptyIsEmpty
  where
    showShrinkInt n =
      putStrLn ("  shrink (" ++ show (n :: Int) ++ ") = " ++ show (shrink n))

-- 契約1: 縮小候補は必ず「より小さい」
prop_intShrinkSmaller :: Int -> Bool
prop_intShrinkSmaller n = all (\m -> abs m < abs n || (abs m == abs n && m > n)) (shrink n)

prop_listShrinkSmaller :: [Int] -> Bool
prop_listShrinkSmaller xs = all (\ys -> length ys < length xs || ys /= xs) (shrink xs)

-- 契約2: 有限である (ここでは「1000件以内」で確認)
prop_shrinkFinite :: [Int] -> Bool
prop_shrinkFinite xs = length (take 1001 (shrink xs)) <= 1000

-- 最小値には縮小候補がない
prop_shrinkEmptyIsEmpty :: Bool
prop_shrinkEmptyIsEmpty = null (shrink ([] :: [Int])) && null (shrink (0 :: Int))

-- 出力から読み取れること:
--
--   shrink 100 = [0,50,75,88,94,97,99]
--     -> 0 に向かって二分探索のように詰めていく。まず 0 を試すのが重要。
--
--   shrink (-7) = [7,0,-4,-6]
--     -> 符号を反転した 7 も候補になる (絶対値が同じなら正のほうが「小さい」扱い)
--
--   shrink [1,2,3] = [[],[2,3],[1,3],[1,2],[0,2,3],[1,0,3],[1,1,3],[1,2,0],[1,2,2]]
--     -> まず空リスト、次に「1要素削ったもの」、最後に「要素を小さくしたもの」。
--        この順番が大事で、先頭の候補ほど大きく縮まります。
--
--   shrink (Just 3) = [Nothing,Just 0,Just 2]
--     -> Nothing が最優先。
--
-- QuickCheck の縮小アルゴリズム:
--   1. shrink で候補リストを得る
--   2. 先頭から順に試す
--   3. 「まだ失敗する」候補が見つかったら、それを新しい反例にして 1 に戻る
--   4. どの候補でも失敗しなくなったら終了
--
-- つまり「貪欲法」です。最小の反例が保証されるわけではありませんが、
-- 候補の順番を工夫することで、実用上は十分小さくなります。
