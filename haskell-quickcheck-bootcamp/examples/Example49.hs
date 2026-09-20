-- Example 49: 自作の型に shrink を書く
--
-- 実行: runghc Example49.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- (1) 積型 (フィールドが並ぶ型)
------------------------------------------------------------
data Point = Point Int Int
  deriving (Show, Eq)

instance Arbitrary Point where
  arbitrary = Point <$> arbitrary <*> arbitrary

  -- 定石: 「フィールドを1つずつ縮める」候補を並べる。
  --       リスト内包表記で書くと簡潔です。
  shrink (Point x y) =
    [ Point x' y  | x' <- shrink x ] ++
    [ Point x  y' | y' <- shrink y ]

-- タプルに変換して shrink を借りる書き方もあります。
-- フィールドが多いときはこちらが楽です。
data Point3 = Point3 Int Int Int
  deriving (Show, Eq)

instance Arbitrary Point3 where
  arbitrary = Point3 <$> arbitrary <*> arbitrary <*> arbitrary
  shrink (Point3 x y z) =
    [ Point3 x' y' z' | (x', y', z') <- shrink (x, y, z) ]

------------------------------------------------------------
-- (2) 和型 (選択肢がある型)
------------------------------------------------------------
data Shape
  = Circle Int
  | Square Int
  | Rect Int Int
  deriving (Show, Eq)

instance Arbitrary Shape where
  arbitrary = oneof
    [ Circle <$> arbitrary
    , Square <$> arbitrary
    , Rect <$> arbitrary <*> arbitrary
    ]

  -- 定石:
  --   a. 「より単純なコンストラクタ」に変換する候補を先に置く
  --   b. 次に「同じコンストラクタでフィールドを縮めた」候補を置く
  shrink (Circle r)  = [ Circle r' | r' <- shrink r ]
  shrink (Square s)  = Circle s : [ Square s' | s' <- shrink s ]
  shrink (Rect w h)  =
    [ Square w, Square h ] ++              -- より単純な形へ
    [ Rect w' h | w' <- shrink w ] ++
    [ Rect w h' | h' <- shrink h ]

------------------------------------------------------------
-- (3) newtype (中身の shrink をそのまま借りる)
------------------------------------------------------------
newtype Score = Score Int
  deriving (Show, Eq)

instance Arbitrary Score where
  arbitrary = Score <$> choose (0, 100)
  -- 中身を縮めるだけ。ただし範囲外にならないよう filter します。
  shrink (Score n) = [ Score n' | n' <- shrink n, n' >= 0, n' <= 100 ]

------------------------------------------------------------
-- わざと失敗するプロパティで、縮小の効果を見る
------------------------------------------------------------
prop_pointSmall :: Point -> Bool
prop_pointSmall (Point x y) = x + y < 10

prop_point3Small :: Point3 -> Bool
prop_point3Small (Point3 x y z) = x + y + z < 10

prop_shapeArea :: Shape -> Bool
prop_shapeArea s = area s < 100
  where
    area (Circle r) = 3 * r * r
    area (Square a) = a * a
    area (Rect w h) = w * h

prop_scoreSmall :: Score -> Bool
prop_scoreSmall (Score n) = n < 50

-- shrink の契約が守られているかを確かめるプロパティ
prop_shapeShrinkTerminates :: Shape -> Bool
prop_shapeShrinkTerminates s = s `notElem` shrink s

prop_scoreShrinkInRange :: Score -> Bool
prop_scoreShrinkInRange sc = all valid (shrink sc)
  where valid (Score n) = n >= 0 && n <= 100

main :: IO ()
main = do
  putStrLn "--- what the shrink functions produce ---"
  putStrLn ("  shrink (Point 3 4)   = " ++ show (shrink (Point 3 4)))
  putStrLn ("  shrink (Rect 2 3)    = " ++ show (shrink (Rect 2 3)))
  putStrLn ("  shrink (Square 4)    = " ++ show (shrink (Square 4)))
  putStrLn ("  shrink (Circle 4)    = " ++ show (shrink (Circle 4)))
  putStrLn ("  shrink (Score 80)    = " ++ show (shrink (Score 80)))
  putStrLn ""

  putStrLn "--- counterexamples are now small ---"
  putStrLn "Point:"   >> quickCheck prop_pointSmall
  putStrLn "Point3:"  >> quickCheck prop_point3Small
  putStrLn "Shape:"   >> quickCheck prop_shapeArea
  putStrLn "Score:"   >> quickCheck prop_scoreSmall
  putStrLn ""

  putStrLn "--- the shrink functions obey the contract ---"
  putStr "shape shrink terminates : " >> quickCheck prop_shapeShrinkTerminates
  putStr "score shrink in range   : " >> quickCheck prop_scoreShrinkInRange

-- 書き方の型 (テンプレート):
--
--   積型:
--     shrink (C a b c) =
--       [ C a' b  c  | a' <- shrink a ] ++
--       [ C a  b' c  | b' <- shrink b ] ++
--       [ C a  b  c' | c' <- shrink c ]
--
--   または
--     shrink (C a b c) = [ C a' b' c' | (a',b',c') <- shrink (a,b,c) ]
--
--   和型:
--     shrink (Complex ...) = [ Simple ... ] ++ [ Complex ... ]
--       -- 単純なコンストラクタへの変換を先に置く
--
--   newtype:
--     shrink (N x) = [ N x' | x' <- shrink x, 不変条件を満たす ]
--
-- 大事なこと: 「小さい候補ほど先に置く」。
-- QuickCheck は先頭から試して、最初に見つかった失敗候補を採用します。
-- 順番が効率と結果の両方に効きます。
