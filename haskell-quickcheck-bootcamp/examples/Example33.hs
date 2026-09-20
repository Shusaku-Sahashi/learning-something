-- Example 33: 再帰的なデータ型 (1) 素朴に書くと壊れる
--
-- 再帰的な型 (木、式、JSON など) の生成は、Arbitrary 実装で一番ハマる場所です。
-- まず「何が起きるか」を体験します。
--
-- 実行: runghc Example33.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 二分木
------------------------------------------------------------
data Tree
  = Leaf
  | Node Tree Int Tree
  deriving (Show)

size :: Tree -> Int
size Leaf         = 0
size (Node l _ r) = size l + 1 + size r

depth :: Tree -> Int
depth Leaf         = 0
depth (Node l _ r) = 1 + max (depth l) (depth r)

------------------------------------------------------------
-- 素朴な実装: これは危険
------------------------------------------------------------
-- 「Leaf か Node のどちらか」を等確率で選ぶと、
-- Node を選ぶたびに枝が2本に増え、平均すると木が無限に成長します。
-- (正確には、分岐数の期待値が 1 を超えると、有限で止まる保証がなくなります)
--
--   genTreeNaive = oneof [ pure Leaf, Node <$> genTreeNaive <*> arbitrary <*> genTreeNaive ]
--
-- これを実行するとメモリを食いつぶして固まります。
-- 実際に固めると困るので、ここでは「Leaf を選びやすくした版」で
-- どれくらい危ういかだけ見ます。
genTreeRisky :: Gen Tree
genTreeRisky = frequency
  [ (7, pure Leaf)
  , (3, Node <$> genTreeRisky <*> arbitrary <*> genTreeRisky)
  ]

------------------------------------------------------------
-- サイズで制御する実装: これが正解
------------------------------------------------------------
-- sized でサイズを受け取り、再帰するたびに減らします。
-- サイズが 0 になったら必ず Leaf を返すので、必ず停止します。
genTreeSized :: Gen Tree
genTreeSized = sized go
  where
    go 0 = pure Leaf
    go n = frequency
      [ (1, pure Leaf)
      , (3, Node <$> go (n `div` 2) <*> arbitrary <*> go (n `div` 2))
      ]

instance Arbitrary Tree where
  arbitrary = genTreeSized

prop_treeTerminates :: Tree -> Bool
prop_treeTerminates t = size t >= 0

prop_depthBound :: Tree -> Bool
prop_depthBound t = depth t <= size t

main :: IO ()
main = do
  putStrLn "--- risky generator: sizes of 20 samples ---"
  putStrLn "  (frequency 7:3 keeps it finite on average, but the tail is long)"
  risky <- sequence (replicate 20 (generate genTreeRisky))
  print (map size risky)
  putStrLn ("  max size seen: " ++ show (maximum (map size risky)))

  putStrLn ""
  putStrLn "--- sized generator: sizes of 20 samples ---"
  sizedTs <- sequence (replicate 20 (generate genTreeSized))
  print (map size sizedTs)
  putStrLn ("  max size seen: " ++ show (maximum (map size sizedTs)))

  putStrLn ""
  putStrLn "--- sized generator grows with the size parameter ---"
  small <- sequence (replicate 10 (generate (resize 1 genTreeSized)))
  big   <- sequence (replicate 10 (generate (resize 50 genTreeSized)))
  putStrLn ("  resize 1  : " ++ show (map size small))
  putStrLn ("  resize 50 : " ++ show (map size big))

  putStrLn ""
  putStrLn "--- properties ---"
  putStr "terminates     : " >> quickCheck prop_treeTerminates
  putStr "depth <= size  : " >> quickCheck prop_depthBound

-- 覚えておくべきルール:
--
--   再帰的な型の Arbitrary は、必ず sized で書く。
--
-- 理由:
--   * 停止することが保証される (サイズが 0 になれば終端を返す)
--   * サイズを上げれば大きい構造も試せる (maxSize で調整可能)
--   * 縮小 (shrink) と相性が良い
--
-- frequency で重みを調整するだけでは不十分です。
-- 平均的には止まっても、運悪く巨大な木を引く可能性が残り、
-- テストが突然フリーズする原因になります。
