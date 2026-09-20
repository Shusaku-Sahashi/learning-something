-- Example 18: パターン7「構造に沿った性質」
--
-- 再帰的なデータ (リスト、木) を扱う関数には、
-- 「構造の組み立て方に沿った性質」が必ずあります。
--
-- 実行: runghc Example18.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- リストの構造: [] と (x:xs) と (xs ++ ys)
------------------------------------------------------------
prop_lengthAppend :: [Int] -> [Int] -> Property
prop_lengthAppend xs ys = length (xs ++ ys) === length xs + length ys

prop_reverseAppend :: [Int] -> [Int] -> Property
prop_reverseAppend xs ys = reverse (xs ++ ys) === reverse ys ++ reverse xs

prop_mapAppend :: [Int] -> [Int] -> Property
prop_mapAppend xs ys = map negate (xs ++ ys) === map negate xs ++ map negate ys

prop_sumAppend :: [Int] -> [Int] -> Property
prop_sumAppend xs ys = sum (xs ++ ys) === sum xs + sum ys

prop_lengthCons :: Int -> [Int] -> Property
prop_lengthCons x xs = length (x : xs) === 1 + length xs

prop_takeDrop :: Int -> [Int] -> Property
prop_takeDrop n xs = take n xs ++ drop n xs === xs

prop_splitAt :: Int -> [Int] -> Property
prop_splitAt n xs = splitAt n xs === (take n xs, drop n xs)

------------------------------------------------------------
-- 木の構造: Leaf と Node
------------------------------------------------------------
data Tree = Leaf | Node Tree Int Tree
  deriving (Show)

instance Arbitrary Tree where
  arbitrary = sized go
    where
      go 0 = pure Leaf
      go n = frequency
        [ (1, pure Leaf)
        , (3, Node <$> go (n `div` 2) <*> arbitrary <*> go (n `div` 2))
        ]

size :: Tree -> Int
size Leaf         = 0
size (Node l _ r) = size l + 1 + size r

depth :: Tree -> Int
depth Leaf         = 0
depth (Node l _ r) = 1 + max (depth l) (depth r)

toList :: Tree -> [Int]
toList Leaf         = []
toList (Node l x r) = toList l ++ [x] ++ toList r

mirror :: Tree -> Tree
mirror Leaf         = Leaf
mirror (Node l x r) = Node (mirror r) x (mirror l)

-- 構造に沿った性質
prop_sizeIsLength :: Tree -> Property
prop_sizeIsLength t = size t === length (toList t)

prop_depthBound :: Tree -> Bool
prop_depthBound t = depth t <= size t

prop_mirrorTwice :: Tree -> Property
prop_mirrorTwice t = toList (mirror (mirror t)) === toList t

prop_mirrorReverses :: Tree -> Property
prop_mirrorReverses t = toList (mirror t) === reverse (toList t)

prop_mirrorKeepsSize :: Tree -> Property
prop_mirrorKeepsSize t = size (mirror t) === size t

main :: IO ()
main = do
  putStrLn "--- lists ---"
  putStr "length (xs++ys)  : " >> quickCheck prop_lengthAppend
  putStr "reverse (xs++ys) : " >> quickCheck prop_reverseAppend
  putStr "map over ++      : " >> quickCheck prop_mapAppend
  putStr "sum over ++      : " >> quickCheck prop_sumAppend
  putStr "length (x:xs)    : " >> quickCheck prop_lengthCons
  putStr "take ++ drop     : " >> quickCheck prop_takeDrop
  putStr "splitAt          : " >> quickCheck prop_splitAt
  putStrLn ""
  putStrLn "--- trees ---"
  putStr "size = length    : " >> quickCheck prop_sizeIsLength
  putStr "depth <= size    : " >> quickCheck prop_depthBound
  putStr "mirror twice     : " >> quickCheck prop_mirrorTwice
  putStr "mirror reverses  : " >> quickCheck prop_mirrorReverses
  putStr "mirror keeps size: " >> quickCheck prop_mirrorKeepsSize

-- Tree の Arbitrary インスタンスに sized を使っている理由は Example 38-39 で扱います。
-- 今は「再帰的な型はサイズを絞らないと無限に大きくなる」とだけ覚えてください。
