-- Example 31: 自作の型に Arbitrary を実装する
--
-- ここから Ch4「自分のデータ型をどう生成するか」に入ります。
--
-- 実行: runghc Example31.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- (1) 一番単純な形: フィールドが全部 Arbitrary な型
------------------------------------------------------------
data Point = Point Int Int
  deriving (Show, Eq)

instance Arbitrary Point where
  arbitrary = Point <$> arbitrary <*> arbitrary

-- 使う側は今までどおり書けます。forAll は要りません。
prop_pointEq :: Point -> Bool
prop_pointEq p = p == p

------------------------------------------------------------
-- (2) 範囲を絞りたい場合
------------------------------------------------------------
data Screen = Screen Int Int
  deriving (Show, Eq)

instance Arbitrary Screen where
  arbitrary = Screen <$> choose (0, 1919) <*> choose (0, 1079)

prop_screenInRange :: Screen -> Bool
prop_screenInRange (Screen x y) = x >= 0 && x < 1920 && y >= 0 && y < 1080

------------------------------------------------------------
-- (3) 不変条件がある型
------------------------------------------------------------
-- 「下限 <= 上限」でなければならない区間
data Range = Range Int Int
  deriving (Show, Eq)

mkRange :: Int -> Int -> Range
mkRange a b = Range (min a b) (max a b)

instance Arbitrary Range where
  -- 2つ生成してから小さい順に並べる。これが一番安全で速い作り方です。
  arbitrary = mkRange <$> arbitrary <*> arbitrary

rangeContains :: Int -> Range -> Bool
rangeContains x (Range lo hi) = lo <= x && x <= hi

rangeLength :: Range -> Int
rangeLength (Range lo hi) = hi - lo

prop_rangeWellFormed :: Range -> Bool
prop_rangeWellFormed (Range lo hi) = lo <= hi

prop_rangeLengthNonNegative :: Range -> Bool
prop_rangeLengthNonNegative r = rangeLength r >= 0

prop_rangeContainsEnds :: Range -> Bool
prop_rangeContainsEnds r@(Range lo hi) = rangeContains lo r && rangeContains hi r

------------------------------------------------------------
-- (4) 他の型を含む型
------------------------------------------------------------
data Shape
  = Circle Point Int
  | Rectangle Point Point
  deriving (Show, Eq)

instance Arbitrary Shape where
  arbitrary = oneof
    [ Circle <$> arbitrary <*> choose (0, 100)
    , Rectangle <$> arbitrary <*> arbitrary
    ]

prop_shapeShowRead :: Shape -> Bool
prop_shapeShowRead s = length (show s) > 0

main :: IO ()
main = do
  putStrLn "--- Point ---"
  ps <- sample' (arbitrary :: Gen Point)
  mapM_ print (take 5 ps)
  quickCheck prop_pointEq

  putStrLn "--- Screen (constrained ranges) ---"
  ss <- sample' (arbitrary :: Gen Screen)
  mapM_ print (take 5 ss)
  quickCheck prop_screenInRange

  putStrLn "--- Range (invariant: lo <= hi) ---"
  rs <- sample' (arbitrary :: Gen Range)
  mapM_ print (take 5 rs)
  putStr "well formed     : " >> quickCheck prop_rangeWellFormed
  putStr "length >= 0     : " >> quickCheck prop_rangeLengthNonNegative
  putStr "contains ends   : " >> quickCheck prop_rangeContainsEnds

  putStrLn "--- Shape (sum type) ---"
  shs <- sample' (arbitrary :: Gen Shape)
  mapM_ print (take 5 shs)
  quickCheck prop_shapeShowRead

-- 実装の型は必ず Show も必要です。
-- Show がないと、反例を表示できないのでコンパイルが通りません。
-- deriving (Show) を付け忘れて怒られるのは、QuickCheck 初心者の通過儀礼です。
--
-- shrink はまだ書いていません。
-- 書かないと「反例が縮まらない」だけで、動くことは動きます。
-- Ch5 で追加します。
