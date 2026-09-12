-- | QuickCheck を使ってランダムな JSON 値・JSON テキストを生成するための
-- ジェネレータ群。
--
-- このモジュールは「与えられているコード」です。学習者が手を入れる必要はありません。
-- 中身を読まなくてもパーサの実装は進められます。
-- 気になったら docs/02-json-data-type.md で解説しています。
module Json.Gen
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
import Test.QuickCheck hiding (Negative, Positive)

jNullGen :: Gen JValue
jNullGen = pure JNull

jBoolGen :: Gen JValue
jBoolGen = JBool <$> arbitrary

jNumberGen :: Gen JValue
jNumberGen = JNumber <$> arbitrary <*> listOf (choose (0, 9)) <*> arbitrary

jsonStringGen :: Gen String
jsonStringGen =
  concat <$> listOf (oneof [ vectorOf 1 arbitraryUnicodeChar
                           , escapedUnicodeChar ])
  where
    escapedUnicodeChar = ("\\u" ++) <$> vectorOf 4 (elements hexDigitLetters)
    hexDigitLetters    = ['0'..'9'] ++ ['a'..'f'] ++ ['A'..'F']

jStringGen :: Gen JValue
jStringGen = JString <$> jsonStringGen

jArrayGen :: Int -> Gen JValue
jArrayGen = fmap JArray . scale (`div` 2) . listOf . jValueGen . (`div` 2)

jObjectGen :: Int -> Gen JValue
jObjectGen = fmap JObject . scale (`div` 2) . listOf . objKV . (`div` 2)
  where
    objKV n = (,) <$> jsonStringGen <*> jValueGen n

jValueGen :: Int -> Gen JValue
jValueGen n = if n < 5
  then frequency [(4, oneof scalarGens), (1, oneof (compositeGens n))]
  else frequency [(1, oneof scalarGens), (4, oneof (compositeGens n))]
  where
    scalarGens      = [jNullGen , jBoolGen , jNumberGen , jStringGen]
    compositeGens m = [jArrayGen m, jObjectGen m]

instance Arbitrary JValue where
  arbitrary = sized jValueGen
  shrink    = genericShrink

jsonWhitespaceGen :: Gen String
jsonWhitespaceGen =
  scale (round . sqrt . (fromIntegral :: Int -> Double))
  . listOf
  . elements
  $ [' ' , '\n' , '\r' , '\t']

-- | JValue を JSON テキストに変換する。show とは違い、値の周りに
-- ランダムな空白を挿入できるので (show は純粋関数なのでできない)、
-- 「空白の入り方が違っても正しくパースできるか」をテストするのに使う。
stringify :: JValue -> Gen String
stringify = pad . go
  where
    surround l r j = l ++ j ++ r
    pad gen = surround <$> jsonWhitespaceGen <*> jsonWhitespaceGen <*> gen
    commaSeparated = pad . pure . intercalate ","

    go value = case value of
      JArray elements ->
        mapM (pad . stringify) elements
          >>= fmap (surround "[" "]") . commaSeparated
      JObject kvs ->
        mapM stringifyKV kvs >>= fmap (surround "{" "}") . commaSeparated
      _           -> return $ show value

    stringifyKV (k, v) =
      surround <$> pad (pure $ showJSONString k) <*> stringify v <*> pure ":"
