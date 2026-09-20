-- Example 51: genericShrink で shrink を自動導出する
--
-- shrink を手で書くのは定型作業です。Generic を使えば自動化できます。
--
-- 実行: runghc Example51.hs
{-# LANGUAGE DeriveGeneric #-}
module Main (main) where

import GHC.Generics (Generic)
import Test.QuickCheck

------------------------------------------------------------
-- deriving (Generic) を付けて、shrink = genericShrink と書くだけ
------------------------------------------------------------
data Config = Config
  { cHost    :: String
  , cPort    :: Int
  , cRetries :: Int
  , cDebug   :: Bool
  }
  deriving (Show, Eq, Generic)

instance Arbitrary Config where
  arbitrary = Config
    <$> elements ["localhost", "example.com"]
    <*> choose (1, 65535)
    <*> choose (0, 10)
    <*> arbitrary
  shrink = genericShrink

------------------------------------------------------------
-- 和型でも使えます
------------------------------------------------------------
data Shape
  = Circle Int
  | Rect Int Int
  | Poly [Int]
  deriving (Show, Eq, Generic)

instance Arbitrary Shape where
  arbitrary = oneof
    [ Circle <$> choose (1, 100)
    , Rect <$> choose (1, 100) <*> choose (1, 100)
    , Poly <$> listOf (choose (1, 100))
    ]
  shrink = genericShrink

------------------------------------------------------------
-- 再帰型でも使えます
------------------------------------------------------------
data Tree
  = Leaf
  | Node Tree Int Tree
  deriving (Show, Eq, Generic)

instance Arbitrary Tree where
  arbitrary = sized go
    where
      go 0 = pure Leaf
      go n = frequency
        [ (1, pure Leaf)
        , (3, Node <$> go (n `div` 2) <*> choose (0, 100) <*> go (n `div` 2))
        ]
  shrink = genericShrink

size :: Tree -> Int
size Leaf         = 0
size (Node l _ r) = size l + 1 + size r

------------------------------------------------------------
-- 手書きと比べる
------------------------------------------------------------
data ManualShape
  = MCircle Int
  | MRect Int Int
  deriving (Show, Eq)

instance Arbitrary ManualShape where
  arbitrary = oneof [ MCircle <$> choose (1, 100), MRect <$> choose (1, 100) <*> choose (1, 100) ]
  shrink (MCircle r) = [ MCircle r' | r' <- shrink r ]
  shrink (MRect w h) =
    [ MCircle w, MCircle h ] ++
    [ MRect w' h | w' <- shrink w ] ++
    [ MRect w h' | h' <- shrink h ]

------------------------------------------------------------
-- プロパティ
------------------------------------------------------------
prop_configRetries :: Config -> Bool
prop_configRetries c = cRetries c < 3

prop_shapeSmall :: Shape -> Bool
prop_shapeSmall s = area s < 200
  where
    area (Circle r) = 3 * r * r
    area (Rect w h) = w * h
    area (Poly xs)  = sum xs

prop_treeSmall :: Tree -> Bool
prop_treeSmall t = size t < 3

prop_manualShape :: ManualShape -> Bool
prop_manualShape (MCircle r) = r < 50
prop_manualShape (MRect w h) = w * h < 200

main :: IO ()
main = do
  putStrLn "--- genericShrink on a record ---"
  print (take 6 (shrink (Config "example.com" 8080 5 True)))
  putStrLn ""

  putStrLn "--- genericShrink on a sum type ---"
  putStrLn ("  shrink (Rect 4 6) = " ++ show (shrink (Rect 4 6)))
  putStrLn ("  shrink (Poly [1,2]) = " ++ show (shrink (Poly [1, 2])))
  putStrLn ""

  putStrLn "--- genericShrink on a recursive type ---"
  let t = Node (Node Leaf 1 Leaf) 2 (Node Leaf 3 Leaf)
  putStrLn ("  original: " ++ show t)
  mapM_ (putStrLn . ("  -> " ++) . show) (take 5 (shrink t))
  putStrLn ""

  putStrLn "--- counterexamples ---"
  putStrLn "Config:" >> quickCheck prop_configRetries
  putStrLn "Shape:"  >> quickCheck prop_shapeSmall
  putStrLn "Tree:"   >> quickCheck prop_treeSmall
  putStrLn "ManualShape (hand written shrink):" >> quickCheck prop_manualShape

-- genericShrink の挙動:
--   * 積型は「フィールドを1つずつ縮める」候補を出す
--   * 和型は「同じコンストラクタでフィールドを縮める」候補を出す
--   * 再帰型は「部分構造そのもの」も候補に出す
--     (Node l x r を縮めるとき、l や r 単体も候補になる。これが強力です)
--
-- genericShrink を使うべきとき:
--   * 型に不変条件がない (どんなフィールドの組み合わせでも有効)
--   * とりあえず shrink が欲しい
--
-- 手で書くべきとき:
--   * 型に不変条件がある (Example 52 で扱います)
--   * 「この方向に縮めてほしい」という意図がある
--     (例: Rect を Circle に落とす、という和型間の変換)
--
-- genericShrink は不変条件を知らないので、
-- 「ソート済みリスト」や「lo <= hi の範囲型」に使うと壊れた値を作ります。
