-- | Bootcamp.Text のプロパティ。
module Props.Text (group) where

import Bootcamp.Text
import Runner
import Test.QuickCheck

group :: Group
group = Group "Bootcamp.Text"
  [ Prop "chunksOf: concat round trip"  prop_chunksConcat
  , Prop "chunksOf: all but last full"  prop_chunksFull
  , Prop "chunksOf: no empty chunks"    prop_chunksNonEmpty
  , Prop "chunksOf: n <= 0 gives []"    prop_chunksNonPositive
  , Prop "splitOn/joinWith round trip"  prop_splitJoin
  , Prop "splitOn: one more than seps"  prop_splitCount
  , Prop "ellipsis: bounded"            prop_ellipsisBounded
  , Prop "ellipsis: idempotent"         prop_ellipsisIdempotent
  , Prop "ellipsis: short strings kept" prop_ellipsisKeeps
  , Prop "newline: idempotent"          prop_newlineIdempotent
  , Prop "newline: ends with newline"   prop_newlineEnds
  ]

prop_chunksConcat :: Positive Int -> [Int] -> Property
prop_chunksConcat (Positive n) xs = concat (chunksOf n xs) === xs

prop_chunksFull :: Positive Int -> [Int] -> Property
prop_chunksFull (Positive n) xs =
  conjoin [ length c === n | c <- allButLast (chunksOf n xs) ]
  where allButLast ys = take (max 0 (length ys - 1)) ys

prop_chunksNonEmpty :: Positive Int -> [Int] -> Bool
prop_chunksNonEmpty (Positive n) xs = all (not . null) (chunksOf n xs)

prop_chunksNonPositive :: [Int] -> Property
prop_chunksNonPositive xs =
  conjoin [ chunksOf 0 xs === [], chunksOf (-3) xs === [] ]

prop_splitJoin :: Char -> String -> Property
prop_splitJoin sep s = joinWith sep (splitOn sep s) === s

prop_splitCount :: Char -> String -> Property
prop_splitCount sep s =
  length (splitOn sep s) === 1 + length (filter (== sep) s)

prop_ellipsisBounded :: NonNegative Int -> String -> Property
prop_ellipsisBounded (NonNegative n) s =
  counterexample (show (ellipsis n s)) (length (ellipsis n s) <= n)

prop_ellipsisIdempotent :: NonNegative Int -> String -> Property
prop_ellipsisIdempotent (NonNegative n) s =
  ellipsis n (ellipsis n s) === ellipsis n s

prop_ellipsisKeeps :: NonNegative Int -> String -> Property
prop_ellipsisKeeps (NonNegative n) s =
  length s <= n ==> ellipsis n s === s

prop_newlineIdempotent :: String -> Property
prop_newlineIdempotent s =
  ensureTrailingNewline (ensureTrailingNewline s) === ensureTrailingNewline s

prop_newlineEnds :: String -> Bool
prop_newlineEnds s = last (ensureTrailingNewline s) == '\n'
