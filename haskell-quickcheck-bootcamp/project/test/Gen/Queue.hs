-- | Queue の生成器。テスト全体で使い回します。
module Gen.Queue
  ( genQueue
  , genNonEmptyQueue
  , genQueueAndElem
  , shrinkQueue
  ) where

import Bootcamp.Queue
import Test.QuickCheck

-- | スマートコンストラクタ (fromList) を通して作るので、
--   表現不変条件は自動的に保たれます。
genQueue :: Arbitrary a => Gen (Queue a)
genQueue = fromList <$> arbitrary

genNonEmptyQueue :: Arbitrary a => Gen (Queue a)
genNonEmptyQueue = fromList <$> listOf1 arbitrary

-- | キューと、その中に実在する要素。
genQueueAndElem :: (Arbitrary a) => Gen (Queue a, a)
genQueueAndElem = do
  q <- genNonEmptyQueue
  x <- elements (toList q)
  pure (q, x)

-- | 縮小もリストに落としてから作り直します。
--   こうしないと表現不変条件が壊れます。
shrinkQueue :: (Arbitrary a, Eq a) => Queue a -> [Queue a]
shrinkQueue q = [ q' | xs <- shrink (toList q), let q' = fromList xs, q' /= q ]
