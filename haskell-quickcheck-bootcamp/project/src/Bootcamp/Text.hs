-- | 文字列とリストの小さなユーティリティ。
module Bootcamp.Text
  ( chunksOf
  , splitOn
  , joinWith
  , ellipsis
  , ensureTrailingNewline
  ) where

-- | リストを長さ n のかたまりに分割する。n <= 0 のときは空リストを返す。
chunksOf :: Int -> [a] -> [[a]]
chunksOf n xs
  | n <= 0    = []
  | null xs   = []
  | otherwise = take n xs : chunksOf n (drop n xs)

-- | 区切り文字で分割する。区切りが n 個なら結果は n+1 個になる。
splitOn :: Eq a => a -> [a] -> [[a]]
splitOn sep s = case break (== sep) s of
  (a, [])       -> [a]
  (a, _ : rest) -> a : splitOn sep rest

-- | 'splitOn' の逆。
joinWith :: a -> [[a]] -> [a]
joinWith _   []       = []
joinWith _   [x]      = x
joinWith sep (x : xs) = x ++ [sep] ++ joinWith sep xs

-- | 最大 n 文字に収める。切り詰めた場合は末尾に "..." が付き、
--   結果の長さは必ず n 以下になる (n >= 3 のとき)。
ellipsis :: Int -> String -> String
ellipsis n s
  | n <= 0          = ""
  | length s <= n   = s
  | n <= 3          = take n s
  | otherwise       = take (n - 3) s ++ "..."

-- | 末尾に改行がなければ足す。既にあれば何もしない (冪等)。
ensureTrailingNewline :: String -> String
ensureTrailingNewline s
  | not (null s) && last s == '\n' = s
  | otherwise                      = s ++ "\n"
