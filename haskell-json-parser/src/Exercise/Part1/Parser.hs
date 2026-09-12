-- | Part1: バックトラッキング版 JSON パーサ (学習者が実装するファイル)
--
-- ここに実装していきます。対応する解説は docs/03-*.md 〜 docs/11-*.md です。
-- 各関数の型シグネチャは変えずに、`error "TODO: ..."` の部分を実装に置き換えてください。
-- 実装を進めるごとに `cabal test part1` で確認できます。
{-# LANGUAGE DeriveGeneric, TupleSections, LambdaCase #-}
module Exercise.Part1.Parser where

import Control.Applicative (Alternative (..), optional)
import Control.Monad (replicateM)
import Data.Bits (shiftL)
import Data.Char (isDigit, isHexDigit, isSpace, chr, ord, digitToInt)
import Data.Functor (($>))
import Json.Gen -- keep: also brings Json.Gen's `Arbitrary JValue` instance into scope for test/AppendixGenSpec.hs
import Json.Value (JValue (..), isControl)
import Test.QuickCheck hiding (Positive, Negative)

--------------------------------------------------------------------------------
-- docs/03-parser-type-and-char-parser.md
--------------------------------------------------------------------------------

-- | パーサは「入力を受け取り、消費できた分だけ消費して、残りの入力とパース結果を返す関数」
-- のラッパーである。パースに失敗したら Nothing を返す。
newtype Parser i o =
  Parser { runParser :: i -> Maybe (i, o) }

-- | 与えられた1文字にだけマッチするパーサ。
char1 :: Char -> Parser String Char
char1 = error "TODO: char1 を実装する"

-- | 述語を満たす先頭の1要素にマッチする、より汎用的なパーサ。
satisfy :: (a -> Bool) -> Parser [a] a
satisfy = error "TODO: satisfy を実装する"

-- | satisfy を使って char を書き直したもの。
char :: Char -> Parser String Char
char = error "TODO: satisfy を使って char を実装する"

--------------------------------------------------------------------------------
-- docs/04-digit-parser-and-functor.md
--------------------------------------------------------------------------------

-- | 1桁の数字をパースして Int にする、素朴な実装。
digit1 :: Parser String Int
digit1 = error "TODO: digit1 を実装する"

-- | Parser の Functor インスタンス。
-- fmap f parser は「parser の結果に f を適用してから返す」パーサを作る。
instance Functor (Parser i) where
  fmap = error "TODO: Functor (Parser i) の fmap を実装する"

-- | Functor インスタンスを使って書き直した digit。
digit :: Parser String Int
digit = error "TODO: <$> を使って digit を実装する"

--------------------------------------------------------------------------------
-- docs/05-string-parser-and-applicative.md
--------------------------------------------------------------------------------

-- | 与えられた文字列全体にマッチするパーサ、素朴な再帰実装。
string1 :: String -> Parser String String
string1 = error "TODO: string1 を実装する"

-- | Parser の Applicative インスタンス。
-- pure x は入力を消費せず x を返すパーサ。
-- pf <*> po は pf の結果(関数)を po の結果に適用するパーサ。
instance Applicative (Parser i) where
  pure = error "TODO: Applicative (Parser i) の pure を実装する"
  (<*>) = error "TODO: Applicative (Parser i) の <*> を実装する"

-- | Applicative インスタンスを使って書き直した string。
string :: String -> Parser String String
string = error "TODO: <$> と <*> を使って string を実装する"

--------------------------------------------------------------------------------
-- docs/06-jnull-and-alternative.md
--------------------------------------------------------------------------------

jNull :: Parser String JValue
jNull = error "TODO: jNull を実装する ($> を使う)"

-- | Parser の Alternative インスタンス。
-- empty は必ず失敗するパーサ。p1 <|> p2 は p1 が失敗したら p2 を試す
-- (バックトラッキング)。
instance Alternative (Parser i) where
  empty = error "TODO: Alternative (Parser i) の empty を実装する"
  (<|>) = error "TODO: Alternative (Parser i) の <|> を実装する"

jBool :: Parser String JValue
jBool = error "TODO: jBool を実装する (<|> を使う)"

--------------------------------------------------------------------------------
-- docs/07-jstring-and-monad.md
--------------------------------------------------------------------------------

-- | 1つの JSON 文字 (エスケープ・\u 記法・非制御文字のいずれか) をパースする。
jsonChar :: Parser String Char
jsonChar = error "TODO: jsonChar を実装する"

digitsToNumber :: Int -> Integer -> [Int] -> Integer
digitsToNumber base =
  foldl (\num d -> num * fromIntegral base + fromIntegral d)

-- | Parser の Monad インスタンス。
-- p >>= f は「p の結果を使って次にどんなパーサを実行するか決める」ことを可能にする。
instance Monad (Parser i) where
  (>>=) = error "TODO: Monad (Parser i) の >>= を実装する"

-- | サロゲートペア対応込みの JSON 文字列パーサ。
jString :: Parser String JValue
jString = error "TODO: jString を実装する (do 構文 + jsonChar を使う)"

highSurrogateLowerBound, highSurrogateUpperBound :: Int
highSurrogateLowerBound = 0xD800
highSurrogateUpperBound = 0xDBFF

lowSurrogateLowerBound, lowSurrogateUpperBound :: Int
lowSurrogateLowerBound  = 0xDC00
lowSurrogateUpperBound  = 0xDFFF

isHighSurrogate, isLowSurrogate, isSurrogate :: Char -> Bool
isHighSurrogate a =
  ord a >= highSurrogateLowerBound && ord a <= highSurrogateUpperBound
isLowSurrogate a  =
  ord a >= lowSurrogateLowerBound && ord a <= lowSurrogateUpperBound
isSurrogate a     = isHighSurrogate a || isLowSurrogate a

combineSurrogates :: Char -> Char -> Char
combineSurrogates a b = chr $
  ((ord a - highSurrogateLowerBound) `shiftL` 10)
  + (ord b - lowSurrogateLowerBound) + 0x10000

prop_genParseJString :: Property
prop_genParseJString =
  forAllShrink jStringGen shrink $ \js ->
    case runParser jString (show js) of
      Nothing     -> False
      Just (_, o) -> o == js

--------------------------------------------------------------------------------
-- docs/08-jnumber.md
--------------------------------------------------------------------------------

jUInt :: Parser String Integer
jUInt = error "TODO: jUInt を実装する"

digit19 :: Parser String Int
digit19 = digitToInt <$> satisfy (\x -> isDigit x && x /= '0')

digits :: Parser String [Int]
digits = error "TODO: some を使って digits を実装する"

jInt' :: Parser String Integer
jInt' = error "TODO: jInt' を実装する (optional (char '-') を使う)"

signInt :: Maybe Char -> Integer -> Integer
signInt (Just '-') i = negate i
signInt _          i = i

jFrac :: Parser String [Int]
jFrac = error "TODO: jFrac を実装する"

jExp :: Parser String Integer
jExp = error "TODO: jExp を実装する"

jInt :: Parser String JValue
jInt = error "TODO: jInt を実装する"

jIntExp :: Parser String JValue
jIntExp = error "TODO: jIntExp を実装する"

jIntFrac :: Parser String JValue
jIntFrac = error "TODO: jIntFrac を実装する"

jIntFracExp :: Parser String JValue
jIntFracExp = error "TODO: jIntFracExp を実装する"

jNumber :: Parser String JValue
jNumber = error "TODO: 4つの数値パーサを <|> で組み合わせて jNumber を実装する"

prop_genParseJNumber :: Property
prop_genParseJNumber =
  forAllShrink jNumberGen shrink $ \jn ->
    case runParser jNumber (show jn) of
      Nothing     -> False
      Just (_, o) -> o == jn

--------------------------------------------------------------------------------
-- docs/09-jarray-and-jobject.md
--------------------------------------------------------------------------------

surroundedBy ::
  Parser String a -> Parser String b -> Parser String a
surroundedBy = error "TODO: surroundedBy を実装する"

separatedBy :: Parser i v -> Parser i s -> Parser i [v]
separatedBy = error "TODO: separatedBy を実装する (many を使う)"

spaces :: Parser String String
spaces = error "TODO: spaces を実装する (many を使う)"

jArray :: Parser String JValue
jArray = error "TODO: jArray を実装する"

prop_genParseJArray :: Property
prop_genParseJArray =
  forAllShrink (sized jArrayGen) shrink $ \ja -> do
    jas <- dropWhile isSpace <$> stringify ja
    return . counterexample (show jas) $ case runParser jArray jas of
      Nothing     -> False
      Just (_, o) -> o == ja

jObject :: Parser String JValue
jObject = error "TODO: jObject を実装する"

prop_genParseJObject :: Property
prop_genParseJObject =
  forAllShrink (sized jObjectGen) shrink $ \jo -> do
    jos <- dropWhile isSpace <$> stringify jo
    return . counterexample (show jos) $ case runParser jObject jos of
      Nothing     -> False
      Just (_, o) -> o == jo

--------------------------------------------------------------------------------
-- docs/10-jvalue-and-parsejson.md
--------------------------------------------------------------------------------

jValue :: Parser String JValue
jValue = error "TODO: 6つの JSON 値パーサを <|> で組み合わせて jValue を実装する"

parseJSON :: String -> Maybe JValue
parseJSON = error "TODO: parseJSON を実装する"

prop_genParseJSON :: Property
prop_genParseJSON = forAllShrink (sized jValueGen) shrink $ \value -> do
  json <- stringify value
  return . counterexample (show json) . (== Just value) . parseJSON $ json

runTests :: IO ()
runTests = do
  putStrLn "== prop_genParseJString =="
  quickCheck prop_genParseJString

  putStrLn "== prop_genParseJNumber =="
  quickCheck prop_genParseJNumber

  putStrLn "== prop_genParseJArray =="
  quickCheck prop_genParseJArray

  putStrLn "== prop_genParseJObject =="
  quickCheck prop_genParseJObject

  putStrLn "== prop_genParseJSON =="
  quickCheck prop_genParseJSON
