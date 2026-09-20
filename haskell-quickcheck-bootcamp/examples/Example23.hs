-- Example 23: Arbitrary 型クラス
--
-- ここから Ch3「入力をどう作るか」に入ります。
-- QuickCheck が値をランダムに作れるのは、Arbitrary 型クラスのおかげです。
--
--   class Arbitrary a where
--     arbitrary :: Gen a          -- 値を1つ作る方法
--     shrink    :: a -> [a]       -- 失敗したときに小さくする方法 (Ch5)
--
-- 実行: runghc Example23.hs
module Main (main) where

import Test.QuickCheck

-- generate :: Gen a -> IO a
--   Gen から実際の値を1つ取り出します。
--
-- sample  :: Show a => Gen a -> IO ()
--   だんだん大きくなるサンプルを 11 個表示します。
--
-- sample' :: Gen a -> IO [a]
--   同じものをリストで返します。

main :: IO ()
main = do
  putStrLn "--- generate: one value at a time ---"
  n  <- generate (arbitrary :: Gen Int)
  b  <- generate (arbitrary :: Gen Bool)
  xs <- generate (arbitrary :: Gen [Int])
  print n
  print b
  print xs
  putStrLn ""

  putStrLn "--- sample: Gen Int ---"
  sample (arbitrary :: Gen Int)
  putStrLn ""

  putStrLn "--- sample: Gen Bool ---"
  sample (arbitrary :: Gen Bool)
  putStrLn ""

  putStrLn "--- sample: Gen [Int] ---"
  sample (arbitrary :: Gen [Int])
  putStrLn ""

  putStrLn "--- sample: Gen (Maybe Char) ---"
  sample (arbitrary :: Gen (Maybe Char))
  putStrLn ""

  putStrLn "--- sample: Gen (Int, Bool, String) ---"
  sample (arbitrary :: Gen (Int, Bool, String))

-- sample の出力を見ると、だんだん値が大きくなっていくのが分かります。
-- これは QuickCheck が「サイズ」を 0 から少しずつ上げながら生成するからです。
--
--   最初のほう: 0, -1, 2, ...        小さい値・短いリスト
--   後ろのほう: -14, 27, ...         大きい値・長いリスト
--
-- 小さい値から始めるのには理由があります:
--   * 小さい入力のほうがバグを踏みやすい (境界値、空、1要素)
--   * 小さい反例のほうがデバッグしやすい
--
-- 標準で Arbitrary を持っている主な型:
--   Int, Integer, Word, Float, Double, Char, Bool, Ordering, ()
--   [a], Maybe a, Either a b, タプル (2〜9要素)
--   Data.Map, Data.Set (containers との統合パッケージが必要な場合あり)
--   関数 (a -> b) ... ただし Show できないので Fun を使う (Example 45)
