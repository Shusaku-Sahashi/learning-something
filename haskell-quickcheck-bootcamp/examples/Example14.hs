-- Example 14: パターン3「冪等性 (idempotence)」
--
--   f (f x) == f x
--
-- 「正規化」「整形」「重複除去」「ソート」など、
-- 「もう一度やっても何も起きないはず」の関数に使えます。
--
-- 実行: runghc Example14.hs
module Main (main) where

import Data.Char (toLower)
import Data.List (sort, nub)
import Test.QuickCheck

prop_sortIdempotent :: [Int] -> Property
prop_sortIdempotent xs = sort (sort xs) === sort xs

prop_nubIdempotent :: [Int] -> Property
prop_nubIdempotent xs = nub (nub xs) === nub xs

prop_absIdempotent :: Int -> Property
prop_absIdempotent x = abs (abs x) === abs x

prop_toLowerIdempotent :: String -> Property
prop_toLowerIdempotent s = map toLower (map toLower s) === map toLower s

------------------------------------------------------------
-- 自作の正規化関数でバグを見つける
------------------------------------------------------------
-- 「前後の空白を削り、連続する空白を1つにまとめる」つもりの関数 (バグあり)
normalizeBuggy :: String -> String
normalizeBuggy = unwords . words . filter (/= '\t')

-- 次はわざと壊した版です。
-- 意図は「末尾に改行がなければ足す」。実務でよく書く処理です。
-- ところが実装は「常に足す」になっているので、呼ぶたびに改行が増えていきます。
ensureNewlineBuggy :: String -> String
ensureNewlineBuggy s = s ++ "\n"

-- 正しい実装
ensureNewline :: String -> String
ensureNewline s
  | not (null s) && last s == '\n' = s
  | otherwise                      = s ++ "\n"

prop_normalizeIdempotent :: String -> Property
prop_normalizeIdempotent s = normalizeBuggy (normalizeBuggy s) === normalizeBuggy s

prop_ensureNewlineBuggy :: String -> Property
prop_ensureNewlineBuggy s = ensureNewlineBuggy (ensureNewlineBuggy s) === ensureNewlineBuggy s

prop_ensureNewline :: String -> Property
prop_ensureNewline s = ensureNewline (ensureNewline s) === ensureNewline s

main :: IO ()
main = do
  putStr "sort            : " >> quickCheck prop_sortIdempotent
  putStr "nub             : " >> quickCheck prop_nubIdempotent
  putStr "abs             : " >> quickCheck prop_absIdempotent
  putStr "toLower         : " >> quickCheck prop_toLowerIdempotent
  putStr "normalize       : " >> quickCheck prop_normalizeIdempotent
  putStrLn ""
  putStrLn "--- not idempotent (fails on purpose) ---"
  quickCheck prop_ensureNewlineBuggy
  putStrLn ("  once  : " ++ show (ensureNewlineBuggy "hi"))
  putStrLn ("  twice : " ++ show (ensureNewlineBuggy (ensureNewlineBuggy "hi")))
  putStrLn ""
  putStrLn "--- fixed version ---"
  putStr "ensureNewline   : " >> quickCheck prop_ensureNewline

-- 補足:
--   toLower は Unicode 的には厳密には冪等でないケースが議論されますが、
--   Data.Char.toLower (単一文字変換) の範囲では冪等です。
--
--   冪等性が破れる典型:
--     「あれば足さない」はずが常に足している実装 (上の ensureNewlineBuggy)
--     「長すぎたら切って ... を足す」実装
--     「1回だけ削る / 1段だけ展開する」実装
--     「正規化のつもりが、毎回プレフィックスを足している」実装
--     「エスケープ処理を二重にかけてしまう」実装 (\\ -> \\\\ -> \\\\\\\\)
