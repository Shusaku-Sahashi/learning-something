-- Example 20: パターン9「同じ計算の2つの書き方」
--
-- リファクタリングの安全網になるプロパティです。
-- 「この2つの式は、どんな入力でも同じ値になるはず」を書きます。
--
-- 実行: runghc Example20.hs
module Main (main) where

import Data.List (foldl')
import Test.QuickCheck

-- map の融合 (fusion): 2回走査するのと1回で済ますのは同じ
prop_mapFusion :: [Int] -> Property
prop_mapFusion xs = map (+ 1) (map (* 2) xs) === map ((+ 1) . (* 2)) xs

-- filter の融合
prop_filterFusion :: [Int] -> Property
prop_filterFusion xs =
  filter (> 0) (filter even xs) === filter (\x -> even x && x > 0) xs

-- foldr / foldl は (++) のような非可換演算では違う結果になる。
-- 結合律と単位元があるなら、結果は一致する。
prop_foldrFoldlSum :: [Int] -> Property
prop_foldrFoldlSum xs = foldr (+) 0 xs === foldl (+) 0 xs

-- foldl と foldl' は結果が同じ (違うのは評価戦略だけ)
prop_foldlStrict :: [Int] -> Property
prop_foldlStrict xs = foldl (+) 0 xs === foldl' (+) 0 xs

-- concatMap と concat . map
prop_concatMap :: [Int] -> Property
prop_concatMap xs = concatMap (\x -> [x, x]) xs === concat (map (\x -> [x, x]) xs)

-- reverse を使った書き換え
prop_lastIsHeadReverse :: [Int] -> Property
prop_lastIsHeadReverse xs = not (null xs) ==> last xs === head (reverse xs)

-- zip / unzip
prop_zipUnzip :: [(Int, Bool)] -> Property
prop_zipUnzip ps = uncurry zip (unzip ps) === ps

-- ★ 成り立ちそうで成り立たない例
-- 「unzip してから zip すると元に戻る」は成り立ちますが、
-- 「zip してから unzip すると元に戻る」は、長さが違うと成り立ちません。
prop_unzipZip :: [Int] -> [Bool] -> Property
prop_unzipZip xs bs = unzip (zip xs bs) === (xs, bs)

main :: IO ()
main = do
  putStr "map fusion       : " >> quickCheck prop_mapFusion
  putStr "filter fusion    : " >> quickCheck prop_filterFusion
  putStr "foldr = foldl    : " >> quickCheck prop_foldrFoldlSum
  putStr "foldl = foldl'   : " >> quickCheck prop_foldlStrict
  putStr "concatMap        : " >> quickCheck prop_concatMap
  putStr "last = head.rev  : " >> quickCheck prop_lastIsHeadReverse
  putStr "zip . unzip      : " >> quickCheck prop_zipUnzip
  putStrLn ""
  putStrLn "--- unzip . zip (fails on purpose: lengths differ) ---"
  quickCheck prop_unzipZip

-- この形のプロパティは、こういうときに書きます:
--   * 遅いコードを速く書き直すとき (前後を比較)
--   * 重複したロジックを共通化するとき (共通化前後を比較)
--   * ライブラリの関数に置き換えるとき (自作 vs ライブラリ)
--
-- 書き換えの前に古い実装を oldFoo という名前で残し、
-- prop_sameAsOld を書いてから置き換えると、安心してリファクタできます。
