-- Example 13: パターン2「不変条件 (invariant)」
--
-- 「この操作をしても、これだけは変わらない / 必ず成り立つ」を書きます。
-- 出力の中身を完全に予測できなくても書けるのが強みです。
--
-- 実行: runghc Example13.hs
module Main (main) where

import Data.List (sort, nub)
import Test.QuickCheck

------------------------------------------------------------
-- sort の不変条件を列挙する
------------------------------------------------------------
-- (1) 長さが変わらない
prop_sortLength :: [Int] -> Property
prop_sortLength xs = length (sort xs) === length xs

-- (2) 結果は昇順に並んでいる
prop_sortOrdered :: [Int] -> Bool
prop_sortOrdered xs = isOrdered (sort xs)
  where isOrdered ys = and (zipWith (<=) ys (drop 1 ys))

-- (3) 元のリストの並べ替えになっている (重複の個数まで一致する)
--     注意: ここで「sort xs == sort xs」と書いては意味がありません。
--     検査対象の sort をオラクルに使うと、何も検査できないからです。
--     そこで「各要素の出現回数」を数えて比べます。
prop_sortPermutation :: [Int] -> Bool
prop_sortPermutation xs =
  all (\x -> count x (sort xs) == count x xs) xs
  where count x = length . filter (== x)

-- (4) どの要素も元のリストに含まれている
prop_sortElems :: [Int] -> Bool
prop_sortElems xs = all (`elem` xs) (sort xs)

-- ★ 重要: (2) だけでは不十分です。
--   「常に [] を返す」実装も (2) を満たしてしまいます。
badSort :: [Int] -> [Int]
badSort _ = []

prop_badSortIsOrdered :: [Int] -> Bool
prop_badSortIsOrdered xs = isOrdered (badSort xs)
  where isOrdered ys = and (zipWith (<=) ys (drop 1 ys))

prop_badSortLength :: [Int] -> Property
prop_badSortLength xs = length (badSort xs) === length xs

------------------------------------------------------------
-- nub の不変条件
------------------------------------------------------------
prop_nubNoDup :: [Int] -> Bool
prop_nubNoDup xs = let ys = nub xs in length (nub ys) == length ys

prop_nubSubset :: [Int] -> Bool
prop_nubSubset xs = all (`elem` xs) (nub xs)

prop_nubKeepsAll :: [Int] -> Bool
prop_nubKeepsAll xs = all (`elem` nub xs) xs

main :: IO ()
main = do
  putStrLn "--- sort invariants ---"
  putStr "length preserved : " >> quickCheck prop_sortLength
  putStr "ordered          : " >> quickCheck prop_sortOrdered
  putStr "same multiset    : " >> quickCheck prop_sortPermutation
  putStr "elements kept    : " >> quickCheck prop_sortElems
  putStrLn ""
  putStrLn "--- badSort (always returns []) ---"
  putStr "ordered          : " >> quickCheck prop_badSortIsOrdered
  putStr "length preserved : " >> quickCheck prop_badSortLength
  putStrLn ""
  putStrLn "--- nub invariants ---"
  putStr "no duplicates    : " >> quickCheck prop_nubNoDup
  putStr "is a subset      : " >> quickCheck prop_nubSubset
  putStr "keeps everything : " >> quickCheck prop_nubKeepsAll

-- 教訓:
--   不変条件は「1つでは足りない」ことがほとんどです。
--   badSort のように、一部の性質だけ満たす手抜き実装が作れないか、
--   自問しながらプロパティを足していってください。
--
--   目安: 「この性質を全部満たす、間違った実装を書けるか?」
--         書けるなら、プロパティが足りていません。
