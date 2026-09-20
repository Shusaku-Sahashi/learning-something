-- | Appendix の腕試し用ファイル: src/Json/Gen.hs と同じものを、
-- 何も見ずに自分の手で実装してみる。
--
-- 対応する解説は docs/appendix-quickcheck.md の「8. 腕試し」です。
-- `cabal test appendix-gen` で、あなたがすでに実装した
-- Exercise.Part1.Parser を使ってラウンドトリップ検証します
-- (test/AppendixGenSpec.hs が Part1 に固定で結び付けられているため)。
-- Part1 を先に完成させてから取り組んでください。
--
-- 注意: このファイルでは `instance Arbitrary JValue` を再定義しません。
-- Json.Gen がすでに定義しており、テスト実行時にはそちらが
-- (Exercise.Part1.Parser 経由で) 使われるためです。ここでは `arbitrary`/
-- `shrink` に頼らない、素朴なジェネレータ関数だけを実装します。
module Exercise.Appendix.Gen
  ( jNullGen
  , jBoolGen
  , jNumberGen
  , jsonStringGen
  , jStringGen
  , jArrayGen
  , jObjectGen
  , jValueGen
  , jsonWhitespaceGen
  , stringify
  ) where

import Data.List (intercalate)
import Json.Value (JValue (..), showJSONString)
import Test.QuickCheck

-- | 常に JNull を生成する。
jNullGen :: Gen JValue
jNullGen = error "TODO: jNullGen を実装する (pure を使う)"

-- | ランダムな真偽値を JBool でラップして生成する。
jBoolGen :: Gen JValue
jBoolGen = error "TODO: jBoolGen を実装する (arbitrary と <$> を使う)"

-- | ランダムな整数部・小数部の桁のリスト・指数部を組み合わせて
-- JNumber を生成する。
jNumberGen :: Gen JValue
jNumberGen = error "TODO: jNumberGen を実装する (<$> と <*> を使う)"

-- | JSON 文字列の中身になりうる文字列(Unicode 文字と \\u エスケープが
-- 混ざったもの)を生成する。
jsonStringGen :: Gen String
jsonStringGen =
  error "TODO: jsonStringGen を実装する (listOf, oneof, vectorOf を使う)"

jStringGen :: Gen JValue
jStringGen = error "TODO: jStringGen を実装する (jsonStringGen を使う)"

-- | 大きさの目安(サイズ)を受け取り、JArray を生成する。
-- 再帰する側でサイズを縮めないと生成が終わらなくなるので注意。
jArrayGen :: Int -> Gen JValue
jArrayGen = error "TODO: jArrayGen を実装する (scale, listOf, jValueGen を使う)"

-- | 大きさの目安を受け取り、JObject を生成する。
-- jArrayGen と同じく、再帰する側でサイズを縮めないと生成が終わらなくなるので注意。
jObjectGen :: Int -> Gen JValue
jObjectGen = error "TODO: jObjectGen を実装する (scale, listOf, jValueGen を使う)"

-- | 大きさの目安を受け取り、任意の JValue を生成する。
-- サイズが小さいほどスカラー値、大きいほど複合値に偏るようにする。
jValueGen :: Int -> Gen JValue
jValueGen = error "TODO: jValueGen を実装する (frequency, oneof を使う)"

-- | JSON の空白文字(' ', '\\n', '\\r', '\\t')だけからなる文字列を生成する。
jsonWhitespaceGen :: Gen String
jsonWhitespaceGen =
  error "TODO: jsonWhitespaceGen を実装する (listOf, elements を使う)"

-- | JValue を JSON テキストに変換する。show と違い、値の前後・区切りに
-- ランダムな空白を挟めるようにする。
stringify :: JValue -> Gen String
stringify = error "TODO: stringify を実装する"
