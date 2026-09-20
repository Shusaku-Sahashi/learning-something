-- | 閉区間 [lo, hi]。lo <= hi が不変条件。
module Bootcamp.Interval
  ( Interval
  , mkInterval
  , lo
  , hi
  , width
  , contains
  , overlaps
  , intersect
  , hull
  , invariant
  ) where

data Interval = Interval Int Int
  deriving (Eq, Ord)

instance Show Interval where
  show (Interval a b) = "[" ++ show a ++ "," ++ show b ++ "]"

invariant :: Interval -> Bool
invariant (Interval a b) = a <= b

-- | スマートコンストラクタ。どんな2値からでも正しい区間を作る。
mkInterval :: Int -> Int -> Interval
mkInterval a b = Interval (min a b) (max a b)

lo, hi :: Interval -> Int
lo (Interval a _) = a
hi (Interval _ b) = b

width :: Interval -> Int
width (Interval a b) = b - a

contains :: Int -> Interval -> Bool
contains x (Interval a b) = a <= x && x <= b

overlaps :: Interval -> Interval -> Bool
overlaps (Interval a1 b1) (Interval a2 b2) = a1 <= b2 && a2 <= b1

-- | 共通部分。重ならないときは Nothing。
intersect :: Interval -> Interval -> Maybe Interval
intersect i1@(Interval a1 b1) i2@(Interval a2 b2)
  | overlaps i1 i2 = Just (Interval (max a1 a2) (min b1 b2))
  | otherwise      = Nothing

-- | 両方を含む最小の区間。
hull :: Interval -> Interval -> Interval
hull (Interval a1 b1) (Interval a2 b2) = Interval (min a1 a2) (max b1 b2)
