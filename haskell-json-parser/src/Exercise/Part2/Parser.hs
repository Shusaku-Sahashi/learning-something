-- | Part2: エラーハンドリング・Zipper版 JSON パーサ (学習者が実装するファイル)
--
-- ここに実装していきます。対応する解説は docs/12-*.md 〜 docs/24-*.md です。
-- 各関数の型シグネチャは変えずに、`error "TODO: ..."` の部分を実装に置き換えてください。
-- Part1 と違い Alternative インスタンスは定義しません(意図的です。docs/14 を参照)。
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE TupleSections #-}
module Exercise.Part2.Parser where

import Control.Applicative (Alternative (..))
import Control.Monad (replicateM)
import Data.Bits (shiftL)
import Data.Char (chr, digitToInt, isDigit, isHexDigit, isSpace, ord)
import Data.Functor (($>))
import qualified Data.List.NonEmpty as NEL
import Data.List (intercalate)
import Data.List.Split (dropFinalBlank, keepDelimsR, onSublist, split)
import Json.Gen -- keep: used by this file's own prop_* tests below, and brings the `Arbitrary JValue` instance into scope
import Json.Value (JValue (..), isControl)
import Test.QuickCheck hiding (Negative, Positive)
import Text.Printf (printf)
import Prelude hiding (lines)

--------------------------------------------------------------------------------
-- docs/13-parseresult-and-parser1.md
--------------------------------------------------------------------------------

-- | パースの結果。失敗したら (最新のものが先頭にきた) エラーメッセージのリスト、
-- 成功したら値を返す。
data ParseResult a = Error [String] | Result a

instance (Show a) => Show (ParseResult a) where
  show (Result res) = show res
  show (Error errs) = formatErrors (reverse errs)
    where
      formatErrors [] = error "No errors to format"
      formatErrors [err] = err
      formatErrors (err : errs') =
        err <> delim <> intercalate delim (map (concatMap padNewline) errs')

      delim = "\n→ "
      padNewline '\n' = '\n' : replicate (length delim - 1) ' '
      padNewline c = [c]

instance Functor ParseResult where
  fmap = error "TODO: Functor ParseResult の fmap を実装する"

instance Applicative ParseResult where
  pure = error "TODO: Applicative ParseResult の pure を実装する"
  (<*>) = error "TODO: Applicative ParseResult の <*> を実装する"

-- | エラー報告に対応した、最初のバージョンの Parser。
-- (このあと Zipper 対応版に置き換わるので 1 サフィックスが付いている)
newtype Parser1 i o
  = Parser1 {runParser1 :: i -> ParseResult (i, o)}

instance Functor (Parser1 i) where
  fmap = error "TODO: Functor (Parser1 i) の fmap を実装する"

instance Applicative (Parser1 i) where
  pure = error "TODO: Applicative (Parser1 i) の pure を実装する"
  (<*>) = error "TODO: Applicative (Parser1 i) の <*> を実装する"

instance Alternative (Parser1 i) where
  empty = error "TODO: Alternative (Parser1 i) の empty を実装する"
  (<|>) = error "TODO: Alternative (Parser1 i) の <|> を実装する"

instance Monad (Parser1 i) where
  (>>=) = error "TODO: Monad (Parser1 i) の >>= を実装する"

parseError1 :: String -> ParseResult a
parseError1 err = Error [err]

throw1 :: String -> Parser1 String o
throw1 = Parser1 . const . parseError1

satisfy1 ::
  (Char -> Bool) -> (Char -> String) -> Parser1 String Char
satisfy1 = error "TODO: satisfy1 を実装する"

char1 :: Char -> Parser1 String Char
char1 c = satisfy1 (== c) $ printf "Expected '%v', got '%v'" c

string1 :: String -> Parser1 String String
string1 = error "TODO: string1 を実装する"

--------------------------------------------------------------------------------
-- docs/14-backtracking-problem.md
--------------------------------------------------------------------------------

-- | バックトラッキング版の jBool。動かしてみるとエラーメッセージが
-- おかしいことに気づくはず (docs/14 参照)。
jBool1 :: Parser1 String JValue
jBool1 = error "TODO: jBool1 を実装する (バグる版でよい)"

-- | 先読み (consume せずに次の文字を覗き見る) をするパーサ。
lookahead1 :: Parser1 String Char
lookahead1 = error "TODO: lookahead1 を実装する"

-- | lookahead1 を使い、バックトラッキングせずに true/false を選択する版。
jBool2 :: Parser1 String JValue
jBool2 = error "TODO: jBool2 を実装する"

--------------------------------------------------------------------------------
-- docs/15-zippers.md
--------------------------------------------------------------------------------

data ListZipper a
  = ListZipper
  { lzLeft :: [a],
    lzFocus :: a,
    lzRight :: [a]
  }
  deriving (Show)

list2zipper :: NEL.NonEmpty a -> ListZipper a
list2zipper list = ListZipper [] (NEL.head list) (NEL.tail list)

lzMoveRight :: ListZipper a -> ListZipper a
lzMoveRight = error "TODO: lzMoveRight を実装する"

lzMoveLeft :: ListZipper a -> ListZipper a
lzMoveLeft = error "TODO: lzMoveLeft を実装する"

zipper2list :: ListZipper a -> NEL.NonEmpty a
zipper2list (ListZipper l f r) = NEL.fromList $ reverse l ++ f : r

--------------------------------------------------------------------------------
-- docs/16-text-zipper.md
--------------------------------------------------------------------------------

data TextZipper a
  = TextZipper
  { tzLeft :: a,
    tzRight :: a,
    tzAbove :: [a],
    tzBelow :: [a]
  }

instance (Show a) => Show (TextZipper a) where
  show (TextZipper left right above below) =
    "TextZipper{left="
      <> show left
      <> ", right="
      <> show right
      <> ", above="
      <> show above
      <> ", below="
      <> show below
      <> "}"

textZipper :: [String] -> TextZipper String
textZipper [] = TextZipper "" "" [] []
textZipper (first : rest) = TextZipper "" first [] rest

currentPosition :: TextZipper String -> (Int, Int)
currentPosition zipper =
  (length (tzAbove zipper) + 1, length (tzLeft zipper) + 1)

currentChar :: TextZipper String -> Maybe Char
currentChar = error "TODO: currentChar を実装する"

-- | Prelude.lines と違い、改行文字 (\n) を残したまま行に分割する。
lines :: String -> [String]
lines = (split . dropFinalBlank . keepDelimsR . onSublist) "\n"

moveByOne :: TextZipper String -> TextZipper String
moveByOne = error "TODO: moveByOne を実装する (3つの場合分け)"

move :: TextZipper String -> TextZipper String
move zipper =
  let zipper' = moveByOne zipper
   in case currentChar zipper' of
        Just _ -> zipper'
        Nothing -> moveByOne zipper'

moveBackByOne :: TextZipper String -> TextZipper String
moveBackByOne = error "TODO: moveBackByOne を実装する (moveByOne の逆)"

--------------------------------------------------------------------------------
-- docs/17-zippered-parser.md
--------------------------------------------------------------------------------

-- | 最終版の Parser。入力を TextZipper として保持し、結果は ParseResult で返す。
newtype Parser i o = Parser
  { runParser_ :: TextZipper i -> ParseResult (TextZipper i, o)
  }

-- | 文字列を受け取って TextZipper に変換し、パース結果の残り入力を
-- 文字列に戻して返すヘルパー。
runParser :: Parser String o -> String -> ParseResult (String, o)
runParser parser input =
  case runParser_ parser (textZipper $ lines input) of
    Error errs -> Error errs
    Result (restZ, output) -> Result (leftOver restZ, output)
  where
    leftOver tz = concat (tzRight tz : tzBelow tz)

instance Functor (Parser i) where
  fmap = error "TODO: Functor (Parser i) の fmap を実装する"

instance Applicative (Parser i) where
  pure = error "TODO: Applicative (Parser i) の pure を実装する"
  (<*>) = error "TODO: Applicative (Parser i) の <*> を実装する"

instance Monad (Parser i) where
  (>>=) = error "TODO: Monad (Parser i) の >>= を実装する"

--------------------------------------------------------------------------------
-- docs/18-errors-with-position.md
--------------------------------------------------------------------------------

-- | エラーメッセージに「何行目・何列目で、周辺のテキストはこう」を付与する。
addPosition :: String -> TextZipper String -> String
addPosition = error "TODO: addPosition を実装する"

showCharForErrorMsg :: Char -> String
showCharForErrorMsg c = case c of
  '\b' -> "\\b"
  '\f' -> "\\f"
  '\n' -> "\\n"
  '\r' -> "\\r"
  '\t' -> "\\t"
  ' ' -> "·"
  _ | isControl c -> "\\" <> show (ord c)
  _ -> [c]

parseError :: String -> TextZipper String -> ParseResult a
parseError err zipper = Error [addPosition err zipper]

throw :: String -> Parser String o
throw = Parser . parseError

-- | 内側のパーサが失敗したら、位置情報付きの追加エラーメッセージを積んでから
-- 失敗を伝播する。
elseThrow :: Parser String o -> String -> Parser String o
elseThrow = error "TODO: elseThrow を実装する"

--------------------------------------------------------------------------------
-- docs/19-basic-parsers-rewrite.md
--------------------------------------------------------------------------------

lookahead :: Parser String Char
lookahead = error "TODO: lookahead を実装する (currentChar を使う、進めない)"

safeLookahead :: Parser String (Maybe Char)
safeLookahead = error "TODO: safeLookahead を実装する (失敗しない lookahead)"

satisfy :: (Char -> Bool) -> String -> Parser String Char
satisfy = error "TODO: satisfy を実装する (成功したら move する)"

char :: Char -> Parser String Char
char c = satisfy (== c) $ printf "Expected '%v'" $ showCharForErrorMsg c

digit :: Parser String Int
digit = digitToInt <$> satisfy isDigit "Expected a digit"

string :: String -> Parser String String
string "" = pure ""
string (c : cs) = (:) <$> char c <*> string cs

--------------------------------------------------------------------------------
-- docs/19-basic-parsers-rewrite.md (jNull, jBool)
--------------------------------------------------------------------------------

jNull :: Parser String JValue
jNull = error "TODO: jNull を実装する (Part1 と同じロジックを新しい string で書く)"

jBool :: Parser String JValue
jBool = error "TODO: jBool を実装する (lookahead で 't'/'f' を場合分け)"

errorMsgForChar :: String -> Char -> String
errorMsgForChar err c = printf err $ showCharForErrorMsg c

--------------------------------------------------------------------------------
-- docs/20-jstring-rewrite.md
--------------------------------------------------------------------------------

-- | 1つの JSON 文字をパースし、(文字, 消費した文字数) を返す。
-- 文字数を返すのは、サロゲート対応に失敗したときに `pushback` で
-- 入力を巻き戻すために必要。
jsonChar :: Parser String (Char, Int)
jsonChar = error "TODO: jsonChar を実装する"

digitsToNumber :: Int -> Integer -> [Int] -> Integer
digitsToNumber base =
  foldl (\num d -> num * fromIntegral base + fromIntegral d)

jString :: Parser String JValue
jString = JString <$> (char '"' *> jString')

jString' :: Parser String String
jString' = error "TODO: jString' を実装する"

jFirstChar :: Parser String String
jFirstChar = error "TODO: jFirstChar を実装する (MultiWayIf を使う)"

-- | count 文字分だけ入力を巻き戻す。
pushback :: Int -> Parser String ()
pushback count = Parser $ \input ->
  Result (iterate moveBackByOne input !! count, ())

jSecondChar :: Char -> Parser String String
jSecondChar = error "TODO: jSecondChar を実装する"

highSurrogateLowerBound, highSurrogateUpperBound :: Int
highSurrogateLowerBound = 0xD800
highSurrogateUpperBound = 0xDBFF

lowSurrogateLowerBound, lowSurrogateUpperBound :: Int
lowSurrogateLowerBound = 0xDC00
lowSurrogateUpperBound = 0xDFFF

isHighSurrogate, isLowSurrogate, isSurrogate :: Char -> Bool
isHighSurrogate a =
  ord a >= highSurrogateLowerBound && ord a <= highSurrogateUpperBound
isLowSurrogate a =
  ord a >= lowSurrogateLowerBound && ord a <= lowSurrogateUpperBound
isSurrogate a = isHighSurrogate a || isLowSurrogate a

combineSurrogates :: Char -> Char -> Char
combineSurrogates a b =
  chr $
    ((ord a - highSurrogateLowerBound) `shiftL` 10)
      + (ord b - lowSurrogateLowerBound)
      + 0x10000

prop_genParseJString :: Property
prop_genParseJString =
  forAllShrink jStringGen shrink $ \js ->
    case runParser jString (show js) of
      Error _ -> False
      Result (_, o) -> o == js

--------------------------------------------------------------------------------
-- docs/21-jnumber-rewrite.md
--------------------------------------------------------------------------------

jUInt :: Parser String Integer
jUInt = error "TODO: jUInt を実装する"

jInt :: Parser String Integer
jInt = error "TODO: jInt を実装する"

digits :: Parser String [Int]
digits = error "TODO: digits を実装する (safeLookahead でループを止める)"

jFrac :: Parser String [Int]
jFrac = error "TODO: jFrac を実装する (elseThrow を使う)"

jExp :: Char -> Parser String Integer
jExp = error "TODO: jExp を実装する"

jNumber :: Parser String JValue
jNumber = error "TODO: jNumber を実装する (do 構文、モナディックスタイル)"

prop_genParseJNumber :: Property
prop_genParseJNumber =
  forAllShrink jNumberGen shrink $ \jn ->
    case runParser jNumber (show jn) of
      Error _ -> False
      Result (_, o) -> o == jn

--------------------------------------------------------------------------------
-- docs/22-jarray-jobject-rewrite.md
--------------------------------------------------------------------------------

surroundedBy :: Parser i a -> Parser i b -> Parser i a
surroundedBy parser1 parser2 = parser2 *> parser1 <* parser2

separatedBy :: Parser String v -> Char -> String -> Parser String [v]
separatedBy = error "TODO: separatedBy を実装する (lookahead 版)"

spaces :: Parser String String
spaces = error "TODO: spaces を実装する (lookahead 版)"

jArray :: Parser String JValue
jArray = error "TODO: jArray を実装する (do 構文、モナディックスタイル)"

prop_genParseJArray :: Property
prop_genParseJArray =
  forAllShrink (sized jArrayGen) shrink $ \ja -> do
    jas <- dropWhile isSpace <$> stringify ja
    return . counterexample (show jas) $ case runParser jArray jas of
      Error _ -> False
      Result (_, o) -> o == ja

jObject :: Parser String JValue
jObject = error "TODO: jObject を実装する"

prop_genParseJObject :: Property
prop_genParseJObject =
  forAllShrink (sized jObjectGen) shrink $ \jo -> do
    jos <- dropWhile isSpace <$> stringify jo
    return . counterexample (show jos) $ case runParser jObject jos of
      Error _ -> False
      Result (_, o) -> o == jo

--------------------------------------------------------------------------------
-- docs/23-jvalue-and-final.md
--------------------------------------------------------------------------------

jValue :: Parser String JValue
jValue = error "TODO: jValue を実装する (lookahead で振り分け)"

parseJSON :: String -> Either String JValue
parseJSON = error "TODO: parseJSON を実装する (Either 版)"

printResult :: Either String JValue -> IO ()
printResult = putStrLn . either ("ERROR:\n" <>) (("RESULT:\n" <>) . show)

prop_genParseJSON :: Property
prop_genParseJSON = forAllShrink (sized jValueGen) shrink $ \value -> do
  json <- stringify value
  return . counterexample (show json) . (== Right value) . parseJSON $ json

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
