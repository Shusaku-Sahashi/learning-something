-- | JSON の値を表す Haskell のデータ型と、それを JSON テキストとして
-- 表示するための Show インスタンス。
--
-- ここは学習者が実装するファイルです。対応する解説は docs/02-json-data-type.md
-- です。`error "TODO: ..."` の部分を実装に置き換えてください。
module Json.Value
  ( JValue (..)
  , showJSONString
  , isControl
  ) where

import Data.Char (ord)
import Data.List (intercalate)
import GHC.Generics (Generic)
import Numeric (showHex)

data JValue
  = JNull
  | JBool Bool
  | JString String
  | JNumber { int :: Integer, frac :: [Int], exponent :: Integer }
  | JArray [JValue]
  | JObject [(String, JValue)]
  deriving (Eq, Generic)

-- | JValue を JSON テキストとして表示する。
instance Show JValue where
  show = error "TODO: JValue を JSON テキストとして表示する show を実装する"

-- | 文字列を、前後にダブルクォートを付け、中身を JSON エスケープ規則で
-- 変換した形で表示する。
showJSONString :: String -> String
showJSONString = error "TODO: showJSONString を実装する"

-- | JSON の仕様が定める「制御文字」かどうかを判定する。
-- Data.Char.isControl とは範囲の定義が異なるので、自前で定義する。
isControl :: Char -> Bool
isControl = error "TODO: isControl を実装する ('\\0'〜'\\31' の範囲)"

-- | 1文字を、必要ならエスケープした形の文字列に変換する。
showJSONChar :: Char -> String
showJSONChar = error "TODO: showJSONChar を実装する"
