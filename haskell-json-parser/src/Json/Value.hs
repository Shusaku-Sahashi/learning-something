-- | JSON の値を表す Haskell のデータ型と、それを JSON テキストとして
-- 表示するための Show インスタンス。
--
-- ここは学習者が実装するファイルです。対応する解説は docs/02-json-data-type.md
-- です。`error "TODO: ..."` の部分を実装に置き換えてください。
module Json.Value
  ( JValue (..),
    showJSONString,
    isControl,
  )
where

import Data.Char (ord)
import Data.List (intercalate)
import GHC.Generics (Generic)
import Numeric (showHex)

data JValue
  = JNull
  | JBool Bool
  | JString String
  | JNumber {int :: Integer, frac :: [Int], exponent :: Integer}
  | JArray [JValue]
  | JObject [(String, JValue)]
  deriving (Eq, Generic)

-- | JValue を JSON テキストとして表示する。
instance Show JValue where
  show value = case value of
    JNull -> "null"
    JBool True -> "true"
    JBool False -> "false"
    JString s -> showJSONString s
    JNumber s [] 0 -> show s
    JNumber s f 0 -> show s ++ "." ++ concatMap show f
    JNumber s [] e -> show s ++ "e" ++ show e
    JNumber s f e -> show s ++ "." ++ concatMap show f ++ "e" ++ show e
    JArray a -> "[" ++ intercalate ", " (map show a) ++ "]"
    JObject o -> "{" ++ intercalate ", " (map showKV o) ++ "}"
    where
      showKV (k, v) = showJSONString k ++ ": " ++ show v

-- | 文字列を、前後にダブルクォートを付け、中身を JSON エスケープ規則で
-- 変換した形で表示する。
showJSONString :: String -> String
showJSONString s = "\"" ++ concatMap showJSONChar s ++ "\""

-- | JSON の仕様が定める「制御文字」かどうかを判定する。
-- Data.Char.isControl とは範囲の定義が異なるので、自前で定義する。
isControl :: Char -> Bool
isControl c = c `elem` ['\0' .. '\31']

-- | 1文字を、必要ならエスケープした形の文字列に変換する。
showJSONChar :: Char -> String
showJSONChar c = case c of
  '\'' -> "'"
  '\"' -> "\\\""
  '\\' -> "\\\\"
  '/' -> "\\/"
  '\b' -> "\\b"
  '\f' -> "\\f"
  '\n' -> "\\n"
  '\r' -> "\\r"
  '\t' -> "\\t"
  _ | isControl c -> "\\u" ++ showJSONNonASCIIChar c
  _ -> [c]
  where
    showJSONNonASCIIChar ch =
      let a = "0000" ++ showHex (ord ch) "" in drop (length a - 4) a
