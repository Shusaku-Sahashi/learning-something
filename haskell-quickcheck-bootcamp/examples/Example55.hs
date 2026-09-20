-- Example 55: 縮小の探索順序と「最小」の意味
--
-- QuickCheck の縮小は貪欲法です。最小の反例を保証しません。
-- どういうときに最小にならないのか、どう対処するのかを見ます。
--
-- 実行: runghc Example55.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 縮小アルゴリズム (擬似コード)
------------------------------------------------------------
--   current = 最初に見つかった反例
--   loop:
--     for candidate in shrink current:
--       if property(candidate) は失敗する:
--         current = candidate
--         goto loop          -- 見つけた時点で、残りの候補は試さない
--     return current         -- どの候補も失敗しなければ終了
--
-- ポイント: 「最初に失敗した候補」を即座に採用します。
--           だから shrink が返すリストの順番が結果を左右します。

------------------------------------------------------------
-- 順番が結果を変える例
------------------------------------------------------------
newtype SmallFirst = SmallFirst Int
  deriving (Show, Eq)

instance Arbitrary SmallFirst where
  arbitrary = SmallFirst <$> choose (0, 1000)
  -- 小さい候補から並べる (QuickCheck の標準的なやり方)
  shrink (SmallFirst n) = [ SmallFirst n' | n' <- shrink n ]

newtype BigFirst = BigFirst Int
  deriving (Show, Eq)

instance Arbitrary BigFirst where
  arbitrary = BigFirst <$> choose (0, 1000)
  -- 「1 ずつ減らす」だけの縮小。正しいが、非常に遅い。
  shrink (BigFirst n) = [ BigFirst (n - 1) | n > 0 ]

prop_smallFirst :: SmallFirst -> Bool
prop_smallFirst (SmallFirst n) = n < 100

prop_bigFirst :: BigFirst -> Bool
prop_bigFirst (BigFirst n) = n < 100

------------------------------------------------------------
-- 局所最小にハマる例
------------------------------------------------------------
-- 「合計がちょうど 10 になる」と失敗するプロパティ。
-- 理想的な最小反例は [10] (要素1個) です。
-- ところが縮小は「要素を削る」「要素を小さくする」しかできず、
-- どちらをやっても合計が 10 から外れて「失敗しなくなる」ため、
-- [4,6] や [3,7] のような2要素の形で止まってしまいます。
newtype SumList = SumList [Int]
  deriving (Show, Eq)

instance Arbitrary SumList where
  arbitrary = SumList <$> listOf (choose (0, 10))
  shrink (SumList xs) = [ SumList ys | ys <- shrink xs ]

prop_sumIsNotTen :: SumList -> Property
prop_sumIsNotTen (SumList xs) =
  counterexample ("sum = " ++ show (sum xs) ++ ", length = " ++ show (length xs))
    (sum xs /= 10)

------------------------------------------------------------
-- 縮小の効き目を数字で見る
------------------------------------------------------------
-- shrink を何回たどれば 0 に着くか
stepsToZero :: (a -> [a]) -> (a -> Bool) -> a -> Int
stepsToZero shr stillFails = go (0 :: Int)
  where
    go k x = case filter stillFails (shr x) of
      []      -> k
      (y : _) -> if k > 5000 then k else go (k + 1) y

main :: IO ()
main = do
  putStrLn "--- halving shrink (standard) ---"
  quickCheck prop_smallFirst
  putStrLn ("  steps from 1000 down to 100: "
              ++ show (stepsToZero (\n -> shrink (n :: Int)) (>= 100) 1000))
  putStrLn ""

  putStrLn "--- decrement-by-one shrink ---"
  quickCheckWith stdArgs { maxShrinks = 2000 } prop_bigFirst
  putStrLn ("  steps from 1000 down to 100: "
              ++ show (stepsToZero (\n -> [ n - 1 | n > (0 :: Int) ]) (>= 100) 1000))
  putStrLn "  ^ same answer, but it took hundreds of shrink steps instead of a handful"
  putStrLn ""

  putStrLn "--- local minimum: small, but not the smallest ---"
  putStrLn "  (hitting sum = 10 by chance needs a few hundred tries)"
  quickCheckWith stdArgs { maxSuccess = 2000 } prop_sumIsNotTen
  putStrLn "  (minimal would be [10]; sometimes you get it, sometimes you stop at [8,2])"
  putStrLn ""

  putStrLn "--- running it several times shows how it varies ---"
  mapM_ (\i -> do
           putStr ("  run " ++ show (i :: Int) ++ ": ")
           r <- quickCheckWithResult stdArgs { chatty = False, maxSuccess = 2000 }
                                     prop_sumIsNotTen
           putStrLn (case r of
                       Failure { failingTestCase = tc } -> unwords (map trim tc)
                       _ -> "passed"))
        [1 .. 8]
  putStrLn ""
  putStrLn "--- why it gets stuck: no single shrink step keeps the sum at 10 ---"
  let stuck = [4, 6] :: [Int]
  putStrLn ("  candidates for " ++ show stuck ++ ":")
  mapM_ (\ys -> putStrLn ("    " ++ show ys ++ "  sum = " ++ show (sum ys)))
        (shrink stuck)
  putStrLn "  none of them sums to 10, so shrinking stops here."

  where
    trim s = takeWhile (/= '\n') s

-- 実務的な結論:
--
--   1. shrink は「半分にする」系にする。1 ずつ減らす実装は遅すぎる。
--      (標準の shrink for Int は 0, n/2, 3n/4, ... と二分探索的に詰めます)
--
--   2. 「最小」は保証されない。局所最小で止まることがある。
--      納得いかない反例が出たら、何度か実行してみる。
--
--   3. shrink の候補は「大きく縮むもの」を先に置く。
--      リストなら [] や「半分に切ったもの」を先頭に。
--
--   4. どうしても最小化したいなら、反例を手で削りながら再実行する。
--      Example 86 の replay を使えば、同じ反例を再現できます。
