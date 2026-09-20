-- | Interval の生成器。
module Gen.Interval
  ( genInterval
  , genOverlappingPair
  , genDisjointPair
  , shrinkInterval
  ) where

import Bootcamp.Interval
import Test.QuickCheck

genInterval :: Gen Interval
genInterval = mkInterval <$> choose (-1000, 1000) <*> choose (-1000, 1000)

-- | 必ず重なる2つの区間。
--   「条件で弾く」のではなく「構成的に作る」のがポイントです。
genOverlappingPair :: Gen (Interval, Interval)
genOverlappingPair = do
  a <- choose (-1000, 1000)
  b <- choose (a, a + 500)
  c <- choose (a, b)            -- 必ず1つ目の中に入る点
  d <- choose (c, c + 500)
  pure (mkInterval a b, mkInterval c d)

-- | 必ず重ならない2つの区間。
genDisjointPair :: Gen (Interval, Interval)
genDisjointPair = do
  a <- choose (-1000, 0)
  b <- choose (a, 0)
  c <- choose (b + 1, b + 500)
  d <- choose (c, c + 500)
  pure (mkInterval a b, mkInterval c d)

shrinkInterval :: Interval -> [Interval]
shrinkInterval i =
  [ j
  | (a, b) <- shrink (lo i, hi i)
  , let j = mkInterval a b
  , j /= i
  ]
