-- Example 28: Gen は Functor / Applicative / Monad
--
-- Gen は普通の Monad です。だから map も do 記法も使えます。
-- これが分かると、生成器を自在に組み立てられるようになります。
--
-- 実行: runghc Example28.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- Functor: 生成した値を変換する
------------------------------------------------------------
-- fmap :: (a -> b) -> Gen a -> Gen b
genDoubled :: Gen Int
genDoubled = fmap (* 2) arbitrary

genUpperWord :: Gen String
genUpperWord = fmap (map toUpper') (elements ["red", "green", "blue"])
  where toUpper' ch = if ch >= 'a' && ch <= 'z' then toEnum (fromEnum ch - 32) else ch

-- (<$>) は fmap の中置版。こちらのほうがよく使われます。
genNegated :: Gen Int
genNegated = negate <$> arbitrary

------------------------------------------------------------
-- Applicative: 複数の生成器を「並べて」組み立てる
------------------------------------------------------------
data Point = Point Int Int
  deriving (Show, Eq)

-- <$> と <*> を並べるだけ。レコード型と相性が良い書き方です。
genPoint :: Gen Point
genPoint = Point <$> choose (0, 100) <*> choose (0, 100)

data Rect = Rect { topLeft :: Point, bottomRight :: Point }
  deriving (Show)

genRect :: Gen Rect
genRect = Rect <$> genPoint <*> genPoint

-- pure :: a -> Gen a
--   「常にこの値」を返す生成器。
genAlwaysZero :: Gen Int
genAlwaysZero = pure 0

------------------------------------------------------------
-- Monad: あとの生成が前の値に依存する場合
------------------------------------------------------------
-- 「x 以上の y」を作りたい。y の範囲が x に依存するので Applicative では書けません。
genOrderedPair :: Gen (Int, Int)
genOrderedPair = do
  x <- choose (0, 100)
  y <- choose (x, 100)     -- ここで x を使っている
  return (x, y)

-- 「リストと、その有効なインデックス」を作る
genListAndIndex :: Gen ([Int], Int)
genListAndIndex = do
  xs <- listOf1 arbitrary
  i  <- choose (0, length xs - 1)
  return (xs, i)

-- 正しい長方形 (左上が右下より小さい) を作る
genValidRect :: Gen Rect
genValidRect = do
  x1 <- choose (0, 100)
  y1 <- choose (0, 100)
  x2 <- choose (x1, 100)
  y2 <- choose (y1, 100)
  return (Rect (Point x1 y1) (Point x2 y2))

main :: IO ()
main = do
  putStrLn "--- Functor ---"
  a <- sample' genDoubled
  print a
  b <- sample' genUpperWord
  print b
  c <- sample' genNegated
  print c

  putStrLn "--- Applicative ---"
  d <- sample' genPoint
  print (take 5 d)
  e <- sample' genRect
  mapM_ print (take 3 e)
  f <- sample' genAlwaysZero
  print f

  putStrLn "--- Monad (dependent generation) ---"
  g <- sample' genOrderedPair
  print (take 8 g)
  h <- sample' genListAndIndex
  mapM_ print (take 4 h)
  i <- sample' genValidRect
  mapM_ print (take 3 i)

  putStrLn ""
  putStrLn "--- properties ---"
  quickCheck (forAll genDoubled even)
  quickCheck (forAll genOrderedPair (\(x, y) -> x <= y))
  quickCheck (forAll genListAndIndex (\(xs, ix) -> ix >= 0 && ix < length xs))
  quickCheck (forAll genValidRect
    (\(Rect (Point x1 y1) (Point x2 y2)) -> x1 <= x2 && y1 <= y2))

-- 使い分けの指針:
--   互いに独立な値を並べる     -> Applicative (<$> <*>)
--   あとの値が前の値に依存する -> Monad (do 記法)
--
-- 「依存する値」を Applicative で無理に作ると、
-- suchThat で弾く羽目になって遅くなります。
-- 依存関係があるなら素直に do で書いてください。
