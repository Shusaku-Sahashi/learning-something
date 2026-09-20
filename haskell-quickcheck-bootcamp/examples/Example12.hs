-- Example 12: 往復プロパティで実際にバグを見つける
--
-- ランレングス符号化 (同じ文字の連続を「文字 + 個数」に圧縮する) を自作し、
-- 往復プロパティでバグをあぶり出します。
--
-- 実行: runghc Example12.hs
module Main (main) where

import Data.Char (isDigit)
import Data.List (group)
import Test.QuickCheck

------------------------------------------------------------
-- バージョン1: 素朴な実装 (バグあり)
------------------------------------------------------------
-- "aaabb" -> "a3b2"
encodeV1 :: String -> String
encodeV1 s = concat [ [head g] ++ show (length g) | g <- group s ]

decodeV1 :: String -> String
decodeV1 [] = []
decodeV1 (c:rest) =
  let (digits, rest') = span isDigit rest
  in replicate (read digits) c ++ decodeV1 rest'

prop_roundTripV1 :: String -> Property
prop_roundTripV1 s = decodeV1 (encodeV1 s) === s

------------------------------------------------------------
-- バージョン2: 修正版
------------------------------------------------------------
-- 問題は「元の文字列に数字が入っている」場合です。
-- "a1" をエンコードすると "a111" になり、デコードすると a が 111 個になります。
-- 数字をエスケープして解決します。
encodeV2 :: String -> String
encodeV2 s = concat [ esc (head g) ++ show (length g) | g <- group s ]
  where esc c | isDigit c = ['\\', c]
              | c == '\\' = "\\\\"
              | otherwise = [c]

decodeV2 :: String -> String
decodeV2 [] = []
decodeV2 ('\\':c:rest) = takeRun c rest
decodeV2 (c:rest)      = takeRun c rest

takeRun :: Char -> String -> String
takeRun c rest =
  let (digits, rest') = span isDigit rest
  in replicate (read digits) c ++ decodeV2 rest'

prop_roundTripV2 :: String -> Property
prop_roundTripV2 s = decodeV2 (encodeV2 s) === s

-- 往復以外にも性質はあります。
-- 例: 1文字だけの文字列は必ず "<文字>1" 形式になる。
prop_singleton :: Char -> Property
prop_singleton c =
  not (isDigit c) && c /= '\\' ==> encodeV2 [c] === [c] ++ "1"

main :: IO ()
main = do
  putStrLn "--- V1 (buggy) ---"
  quickCheck prop_roundTripV1
  putStrLn ("  encodeV1 \"a1\" = " ++ show (encodeV1 "a1"))
  putStrLn ("  decodeV1 (encodeV1 \"a1\") = " ++ show (decodeV1 (encodeV1 "a1")))
  putStrLn ""
  putStrLn "--- V2 (fixed) ---"
  quickCheck prop_roundTripV2
  quickCheck prop_singleton
  putStrLn ("  encodeV2 \"a1\" = " ++ show (encodeV2 "a1"))
  putStrLn ("  roundtrip      = " ++ show (decodeV2 (encodeV2 "a1")))

-- 注目してほしい点:
--   手で単体テストを書くとき、"a1" のような「数字混じり」を試したでしょうか?
--   "aaabb" や "abc" は試しても、"a1" は盲点になりがちです。
--   QuickCheck は Char をランダムに選ぶので、数字が混ざるのは時間の問題です。
--
--   さらに、見つかった反例は "0" のような最小のものに縮小されます。
--   「数字1文字でもう壊れる」と分かれば、原因はすぐ特定できます。
