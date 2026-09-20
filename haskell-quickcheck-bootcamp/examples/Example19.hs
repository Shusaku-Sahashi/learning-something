-- Example 19: パターン8「落ちないこと (全域性)」
--
-- 「正しい答えは分からないが、少なくとも例外で落ちてはいけない」
-- という性質だけでも、十分に価値のあるテストになります。
--
-- 実行: runghc Example19.hs
module Main (main) where

import Test.QuickCheck

-- total :: a -> Property
--   値を完全に評価して、例外 (error, undefined, head [], div by zero など) が
--   起きないことを確かめます。
--
-- テスト対象: 「リストの平均」(わざとバグ入り: 空リストでゼロ除算)
averageBuggy :: [Int] -> Int
averageBuggy xs = sum xs `div` length xs

-- 修正版
average :: [Int] -> Maybe Int
average [] = Nothing
average xs = Just (sum xs `div` length xs)

prop_averageBuggyTotal :: [Int] -> Property
prop_averageBuggyTotal xs = total (averageBuggy xs)

prop_averageTotal :: [Int] -> Property
prop_averageTotal xs = total (average xs)

-- 自作パーサ風の関数。入力が何であれ落ちてはいけない。
parseIntish :: String -> Maybe Int
parseIntish s = case reads s of
  [(n, "")] -> Just n
  _         -> Nothing

prop_parseTotal :: String -> Property
prop_parseTotal s = total (parseIntish s)

-- total は「遅延評価で隠れたエラー」も暴きます。
-- 下の値は、リストの先頭を触るまではエラーになりません。
lazyBomb :: Int -> [Int]
lazyBomb n = [n, error "boom", n + 1]

prop_lazyBombTotal :: Int -> Property
prop_lazyBombTotal n = total (lazyBomb n)

-- 単に (== length) を見るだけなら通ってしまいます。
prop_lazyBombLength :: Int -> Property
prop_lazyBombLength n = length (lazyBomb n) === 3

main :: IO ()
main = do
  putStrLn "--- averageBuggy (fails on purpose) ---"
  quickCheck prop_averageBuggyTotal
  putStrLn ""
  putStrLn "--- fixed / other total functions ---"
  putStr "average        : " >> quickCheck prop_averageTotal
  putStr "parseIntish    : " >> quickCheck prop_parseTotal
  putStrLn ""
  putStrLn "--- hidden lazy error ---"
  putStr "length only    : " >> quickCheck prop_lazyBombLength
  putStrLn "total (fails on purpose):"
  quickCheck prop_lazyBombTotal

-- total は「とりあえず何かテストを書きたい」ときの出発点として優秀です。
-- 性質を1つも思いつかなくても、
--
--   prop_neverCrashes :: Input -> Property
--   prop_neverCrashes x = total (myFunction x)
--
-- と書くだけで、部分関数 (head, fromJust, !!, div) の踏み抜きを検出できます。
--
-- 仕組み: total は内部で NFData を使って値を最後まで評価します。
-- そのため型に NFData インスタンスが必要です
-- (Int, String, リスト, タプル, Maybe などは最初から持っています)。
