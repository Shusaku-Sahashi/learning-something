-- Example 29: サイズパラメータ (sized, resize, scale)
--
-- QuickCheck は生成器に「サイズ」という整数を渡しています。
-- テストが進むにつれて 0 -> maxSize (既定 100) と増えていきます。
-- この値を使うか無視するかで、生成器の性格が変わります。
--
-- 実行: runghc Example29.hs
module Main (main) where

import Test.QuickCheck

-- sized :: (Int -> Gen a) -> Gen a
--   現在のサイズを受け取って生成器を決める。
genSizedInt :: Gen Int
genSizedInt = sized (\n -> choose (0, n))

-- サイズを2乗して使う (大きな値を出したいとき)
genBigger :: Gen Int
genBigger = sized (\n -> choose (0, n * n))

-- サイズを無視する生成器 (常に同じ範囲)
genIgnoresSize :: Gen Int
genIgnoresSize = choose (0, 10)

-- getSize :: Gen Int
--   現在のサイズそのものを取り出す。
genShowSize :: Gen (Int, Int)
genShowSize = do
  n <- getSize
  v <- choose (0, n)
  return (n, v)

-- resize :: Int -> Gen a -> Gen a
--   サイズを固定して生成器を走らせる。
genFixedSize :: Gen [Int]
genFixedSize = resize 5 (listOf arbitrary)

genHugeList :: Gen [Int]
genHugeList = resize 300 (listOf (choose (0, 9)))

-- scale :: (Int -> Int) -> Gen a -> Gen a
--   サイズを関数で変換する。再帰的な生成でよく使います (Example 38)。
genHalfSize :: Gen [Int]
genHalfSize = scale (`div` 2) (listOf arbitrary)

genDoubleSize :: Gen [Int]
genDoubleSize = scale (* 2) (listOf arbitrary)

main :: IO ()
main = do
  putStrLn "--- sized: choose (0, n) ---"
  a <- sample' genSizedInt
  print a

  putStrLn "--- sized: choose (0, n*n) ---"
  b <- sample' genBigger
  print b

  putStrLn "--- ignoring size: always choose (0,10) ---"
  c <- sample' genIgnoresSize
  print c

  putStrLn "--- getSize: (size, value) ---"
  d <- sample' genShowSize
  print d

  putStrLn "--- resize 5 (listOf arbitrary): lengths ---"
  e <- sample' genFixedSize
  print (map length e)

  putStrLn "--- resize 300: lengths ---"
  f <- sample' genHugeList
  print (map length f)

  putStrLn "--- scale (`div` 2): lengths ---"
  g <- sample' genHalfSize
  print (map length g)

  putStrLn "--- scale (*2): lengths ---"
  h <- sample' genDoubleSize
  print (map length h)

  putStrLn ""
  putStrLn "--- how maxSize changes what is generated ---"
  putStrLn "maxSize = 5:"
  quickCheckWith stdArgs { maxSize = 5, maxSuccess = 200 }
    (forAll (arbitrary :: Gen [Int]) (\xs -> length xs <= 5))
  putStrLn "maxSize = 100 (default), same property:"
  quickCheckWith stdArgs { maxSuccess = 200 }
    (forAll (arbitrary :: Gen [Int]) (\xs -> length xs <= 5))

-- サイズの意味は型ごとに決まっています (Arbitrary インスタンスの実装次第):
--   Int       サイズ n に対し、おおよそ [-n, n] の範囲
--   [a]       長さがおおよそ [0, n]
--   Char      サイズに関係なく広い範囲 (実装依存)
--   自作の型  自分で決める
--
-- sized を使うべき場面:
--   * 再帰的なデータ (木、式) の深さを制御したいとき (必須。Example 38)
--   * 「大きい入力でも動くか」を段階的に確かめたいとき
--
-- resize を使うべき場面:
--   * ある生成器だけ小さく (または大きく) したいとき
--   * 「生成器の中で別の生成器を呼ぶが、そこは小さくしたい」とき
