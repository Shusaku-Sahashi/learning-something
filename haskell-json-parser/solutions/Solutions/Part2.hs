-- | Part2(エラーハンドリング・Zipper版)の模範解答。
--
-- abhinavsarkar.net の "JSON Parsing from Scratch in Haskell:
-- Error Reporting" (Part 1 / Part 2) のサンプルコードそのままです。
-- 行き詰まったとき・答え合わせをしたいときに参照してください。
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE TupleSections #-}
module Solutions.Part2 where

import Control.Applicative (Alternative (..))
import Control.Monad (replicateM)
import Data.Bits (shiftL)
import Data.Char (chr, digitToInt, isDigit, isHexDigit, isSpace, ord)
import Data.Functor (($>))
import Data.List (intercalate)
import qualified Data.List.NonEmpty as NEL
import Data.List.Split (dropFinalBlank, keepDelimsR, onSublist, split)
import GHC.Generics (Generic)
import Numeric (showHex)
import Test.QuickCheck hiding (Negative, Positive)
import Text.Printf (printf)
import Prelude hiding (lines)

data JValue
  = JNull
  | JBool Bool
  | JString String
  | JNumber {int :: Integer, frac :: [Int], exponent :: Integer}
  | JArray [JValue]
  | JObject [(String, JValue)]
  deriving (Eq, Generic)

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

showJSONString :: String -> String
showJSONString s = "\"" ++ concatMap showJSONChar s ++ "\""

isControl :: Char -> Bool
isControl c = c `elem` ['\0' .. '\31']

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

jNullGen :: Gen JValue
jNullGen = pure JNull

jBoolGen :: Gen JValue
jBoolGen = JBool <$> arbitrary

jNumberGen :: Gen JValue
jNumberGen = JNumber <$> arbitrary <*> listOf (choose (0, 9)) <*> arbitrary

jsonStringGen :: Gen String
jsonStringGen =
  concat
    <$> listOf
      ( oneof
          [ vectorOf 1 arbitraryUnicodeChar,
            escapedUnicodeChar
          ]
      )
  where
    escapedUnicodeChar = ("\\u" ++) <$> vectorOf 4 (elements hexDigitLetters)
    hexDigitLetters = ['0' .. '9'] ++ ['a' .. 'f'] ++ ['A' .. 'F']

jStringGen :: Gen JValue
jStringGen = JString <$> jsonStringGen

jArrayGen :: Int -> Gen JValue
jArrayGen = fmap JArray . scale (`div` 2) . listOf . jValueGen . (`div` 2)

jObjectGen :: Int -> Gen JValue
jObjectGen = fmap JObject . scale (`div` 2) . listOf . objKV . (`div` 2)
  where
    objKV n = (,) <$> jsonStringGen <*> jValueGen n

jValueGen :: Int -> Gen JValue
jValueGen n =
  if n < 5
    then frequency [(4, oneof scalarGens), (1, oneof (compositeGens n))]
    else frequency [(1, oneof scalarGens), (4, oneof (compositeGens n))]
  where
    scalarGens = [jNullGen, jBoolGen, jNumberGen, jStringGen]
    compositeGens m = [jArrayGen m, jObjectGen m]

instance Arbitrary JValue where
  arbitrary = sized jValueGen
  shrink = genericShrink

jsonWhitespaceGen :: Gen String
jsonWhitespaceGen =
  scale (round . sqrt . (fromIntegral :: Int -> Double))
    . listOf
    . elements
    $ [' ', '\n', '\r', '\t']

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
      _ -> return $ show value

    stringifyKV (k, v) =
      surround <$> pad (pure $ showJSONString k) <*> stringify v <*> pure ":"

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
  fmap _ (Error errs) = Error errs
  fmap f (Result res) = Result (f res)

instance Applicative ParseResult where
  pure = Result
  Error errs <*> _ = Error errs
  Result f <*> result = fmap f result

newtype Parser1 i o
  = Parser1 {runParser1 :: i -> ParseResult (i, o)}

instance Functor (Parser1 i) where
  fmap f parser = Parser1 $ fmap (fmap f) . runParser1 parser

instance Applicative (Parser1 i) where
  pure x = Parser1 $ pure . (,x)
  pf <*> pa = Parser1 $ \input -> case runParser1 pf input of
    Error err -> Error err
    Result (rest, f) -> fmap f <$> runParser1 pa rest

instance Alternative (Parser1 i) where
  empty = Parser1 $ const $ Error ["Unknown error."]
  parser1 <|> parser2 = Parser1 $ \input ->
    case runParser1 parser1 input of
      Result res -> Result res
      Error _ -> runParser1 parser2 input

instance Monad (Parser1 i) where
  parser >>= f = Parser1 $ \input -> case runParser1 parser input of
    Error errs -> Error errs
    Result (rest, output) -> runParser1 (f output) rest

parseError1 :: String -> ParseResult a
parseError1 err = Error [err]

throw1 :: String -> Parser1 String o
throw1 = Parser1 . const . parseError1

satisfy1 ::
  (Char -> Bool) -> (Char -> String) -> Parser1 String Char
satisfy1 predicate mkError = Parser1 $ \case
  (c : cs) | predicate c -> Result (cs, c)
  (c : _) -> parseError1 (mkError c)
  _ -> parseError1 "Empty input"

char1 :: Char -> Parser1 String Char
char1 c = satisfy1 (== c) $ printf "Expected '%v', got '%v'" c

string1 :: String -> Parser1 String String
string1 "" = pure ""
string1 (c : cs) = (:) <$> char1 c <*> string1 cs

jBool1 :: Parser1 String JValue
jBool1 =
  string1 "true" $> JBool True
    <|> string1 "false" $> JBool False

lookahead1 :: Parser1 String Char
lookahead1 = Parser1 $ \case
  input@(c : _) -> Result (input, c)
  _ -> parseError1 "Empty input"

jBool2 :: Parser1 String JValue
jBool2 = do
  c <- lookahead1
  JBool <$> case c of
    't' -> string1 "true" $> True
    'f' -> string1 "false" $> False
    _ ->
      throw1 $
        printf "Expected: 't' for true or 'f' for false; got '%v'" c

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
lzMoveRight (ListZipper l f []) = ListZipper l f []
lzMoveRight (ListZipper l f (x : xs)) = ListZipper (f : l) x xs

lzMoveLeft :: ListZipper a -> ListZipper a
lzMoveLeft (ListZipper [] f r) = ListZipper [] f r
lzMoveLeft (ListZipper (x : xs) f r) = ListZipper xs x (f : r)

zipper2list :: ListZipper a -> NEL.NonEmpty a
zipper2list (ListZipper l f r) = NEL.fromList $ reverse l ++ f : r

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
currentChar zipper = case tzRight zipper of
  [] -> Nothing
  (c : _) -> Just c

lines :: String -> [String]
lines = (split . dropFinalBlank . keepDelimsR . onSublist) "\n"

moveByOne :: TextZipper String -> TextZipper String
moveByOne zipper
  -- not at end of line
  | not $ null (tzRight zipper) =
      zipper
        { tzLeft = head (tzRight zipper) : tzLeft zipper,
          tzRight = tail $ tzRight zipper
        }
  -- at end of line but not at end of input
  | not $ null (tzBelow zipper) =
      zipper
        { tzAbove = tzLeft zipper : tzAbove zipper,
          tzBelow = tail $ tzBelow zipper,
          tzLeft = "",
          tzRight = head $ tzBelow zipper
        }
  -- at end of input
  | otherwise = zipper

move :: TextZipper String -> TextZipper String
move zipper =
  let zipper' = moveByOne zipper
   in case currentChar zipper' of
        Just _ -> zipper'
        Nothing -> moveByOne zipper'

moveBackByOne :: TextZipper String -> TextZipper String
moveBackByOne zipper
  -- not at start of line
  | not $ null (tzLeft zipper) =
      zipper
        { tzLeft = tail $ tzLeft zipper,
          tzRight = head (tzLeft zipper) : tzRight zipper
        }
  -- at start of line but not at start of input
  | not $ null (tzAbove zipper) =
      zipper
        { tzAbove = tail $ tzAbove zipper,
          tzBelow = tzRight zipper : tzBelow zipper,
          tzLeft = head $ tzAbove zipper,
          tzRight = ""
        }
  -- at start of input
  | otherwise = zipper

newtype Parser i o = Parser
  { runParser_ :: TextZipper i -> ParseResult (TextZipper i, o)
  }

runParser :: Parser String o -> String -> ParseResult (String, o)
runParser parser input =
  case runParser_ parser (textZipper $ lines input) of
    Error errs -> Error errs
    Result (restZ, output) -> Result (leftOver restZ, output)
  where
    leftOver tz = concat (tzRight tz : tzBelow tz)

instance Functor (Parser i) where
  fmap f parser = Parser $ fmap (fmap f) . runParser_ parser

instance Applicative (Parser i) where
  pure x = Parser $ pure . (,x)
  pf <*> pa = Parser $ \input -> case runParser_ pf input of
    Error err -> Error err
    Result (rest, f) -> fmap f <$> runParser_ pa rest

instance Monad (Parser i) where
  parser >>= f = Parser $ \input -> case runParser_ parser input of
    Error err -> Error err
    Result (rest, o) -> runParser_ (f o) rest

addPosition :: String -> TextZipper String -> String
addPosition err zipper =
  let (ln, cn) = currentPosition zipper
      err' = printf (err <> " at line %d, column %d: ") ln cn
      left = reverse $ tzLeft zipper
      right = tzRight zipper
      left' = showStr $ drop (length left - ctxLen) left
      right' = showStr $ take ctxLen right
      line = left' <> right'
   in printf
        (err' <> "%s\n%s↑")
        line
        (replicate (length err' + length left') ' ')
  where
    ctxLen = 6
    showStr = concatMap showCharForErrorMsg

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

elseThrow :: Parser String o -> String -> Parser String o
elseThrow parser err = Parser $ \input ->
  case runParser_ parser input of
    Result (rest, a) -> Result (rest, a)
    Error errs -> Error (addPosition err input : errs)

lookahead :: Parser String Char
lookahead = Parser $ \input -> case currentChar input of
  Just c -> Result (input, c)
  Nothing -> parseError "Empty input" input

safeLookahead :: Parser String (Maybe Char)
safeLookahead = Parser $ \input -> case currentChar input of
  Just c -> Result (input, Just c)
  Nothing -> Result (input, Nothing)

satisfy :: (Char -> Bool) -> String -> Parser String Char
satisfy predicate expectation = Parser $ \input -> case currentChar input of
  Just c | predicate c -> Result (move input, c)
  Just c ->
    flip parseError input $
      expectation <> ", got '" <> showCharForErrorMsg c <> "'"
  _ ->
    flip parseError input $
      expectation <> ", but the input is empty"

char :: Char -> Parser String Char
char c = satisfy (== c) $ printf "Expected '%v'" $ showCharForErrorMsg c

digit :: Parser String Int
digit = digitToInt <$> satisfy isDigit "Expected a digit"

string :: String -> Parser String String
string "" = pure ""
string (c : cs) = (:) <$> char c <*> string cs

jNull :: Parser String JValue
jNull = string "null" $> JNull

jBool :: Parser String JValue
jBool = do
  c <- lookahead
  JBool <$> case c of
    't' -> string "true" $> True
    'f' -> string "false" $> False
    _ ->
      throw $
        errorMsgForChar "Expected: 't' for true or 'f' for false; got '%v'" c

errorMsgForChar :: String -> Char -> String
errorMsgForChar err c = printf err $ showCharForErrorMsg c

jsonChar :: Parser String (Char, Int)
jsonChar =
  lookahead >>= \case
    '\\' -> char '\\' *> escapedChar
    _ -> (,1) <$> otherChar
  where
    escapedChar =
      lookahead >>= \case
        '"' -> ('"', 2) <$ char '"'
        '\\' -> ('\\', 2) <$ char '\\'
        '/' -> ('/', 2) <$ char '/'
        'b' -> ('\b', 2) <$ char 'b'
        'f' -> ('\f', 2) <$ char 'f'
        'n' -> ('\n', 2) <$ char 'n'
        'r' -> ('\r', 2) <$ char 'r'
        't' -> ('\t', 2) <$ char 't'
        'u' -> (,6) <$> (char 'u' *> unicodeChar)
        c -> throw $ errorMsgForChar "Invalid escaped character: '%v'" c

    unicodeChar =
      chr . fromIntegral . digitsToNumber 16 0 <$> replicateM 4 hexDigit

    hexDigit =
      digitToInt
        <$> satisfy isHexDigit "Expected a hex digit"

    otherChar =
      satisfy
        (not . isQuoteEscapeOrControl)
        "Did not except '\"', '\\' or control characters"

    isQuoteEscapeOrControl c = c == '\"' || c == '\\' || isControl c

digitsToNumber :: Int -> Integer -> [Int] -> Integer
digitsToNumber base =
  foldl (\num d -> num * fromIntegral base + fromIntegral d)

jString :: Parser String JValue
jString = JString <$> (char '"' *> jString')

jString' :: Parser String String
jString' = do
  c <- lookahead `elseThrow` "Expected rest of a string"
  if c == '"'
    then "" <$ char '"'
    else jFirstChar

jFirstChar :: Parser String String
jFirstChar = do
  (first, count) <- jsonChar
  if
      | not (isSurrogate first) -> (first :) <$> jString'
      | isHighSurrogate first -> jSecondChar first
      | otherwise -> do
          pushback count
          throw
            . errorMsgForChar "Expected a high surrogate character, got '%v'"
            $ first

pushback :: Int -> Parser String ()
pushback count = Parser $ \input ->
  Result (iterate moveBackByOne input !! count, ())

jSecondChar :: Char -> Parser String String
jSecondChar first = do
  (second, count) <-
    jsonChar
      `elseThrow` "Expected a second character of a surrogate pair"
  if isLowSurrogate second
    then (combineSurrogates first second :) <$> jString'
    else do
      pushback count
      throw
        . errorMsgForChar "Expected a low surrogate character, got '%v'"
        $ second

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

jUInt :: Parser String Integer
jUInt =
  (`elseThrow` "Expected an unsigned integer") $
    lookahead >>= \case
      '0' -> fromIntegral <$> digit
      c | isDigit c -> digitsToNumber 10 0 <$> digits
      c -> throw $ printf "Expected a digit, got '%v'" c

jInt :: Parser String Integer
jInt =
  (`elseThrow` "Expected a signed integer") $
    lookahead >>= \case
      '-' -> negate <$> (char '-' *> jUInt)
      _ -> jUInt

digits :: Parser String [Int]
digits = ((:) <$> digit <*> digits') `elseThrow` "Expected digits"
  where
    digits' =
      safeLookahead >>= \case
        Just c | isDigit c -> (:) <$> digit <*> digits'
        _ -> return []

jFrac :: Parser String [Int]
jFrac = (char '.' *> digits) `elseThrow` "Expected a fraction"

jExp :: Char -> Parser String Integer
jExp c = (char c *> jExp') `elseThrow` "Expected an exponent"
  where
    jExp' =
      lookahead >>= \case
        '-' -> negate <$> (char '-' *> jUInt)
        '+' -> char '+' *> jUInt
        _ -> jUInt

jNumber :: Parser String JValue
jNumber = do
  i <- jInt
  safeLookahead >>= \case
    Just '.' -> do
      f <- jFrac
      safeLookahead >>= \case
        Just c' | isExpSym c' -> JNumber i f <$> jExp c' -- int+frac+exp
        _ -> pure $ JNumber i f 0 -- int+frac
    Just c | isExpSym c -> JNumber i [] <$> jExp c -- int+exp
    _ -> pure $ JNumber i [] 0 -- int
  where
    isExpSym c = c == 'e' || c == 'E'

prop_genParseJNumber :: Property
prop_genParseJNumber =
  forAllShrink jNumberGen shrink $ \jn ->
    case runParser jNumber (show jn) of
      Error _ -> False
      Result (_, o) -> o == jn

surroundedBy :: Parser i a -> Parser i b -> Parser i a
surroundedBy parser1 parser2 = parser2 *> parser1 <* parser2

separatedBy :: Parser String v -> Char -> String -> Parser String [v]
separatedBy parser sepChar errMsg = do
  res <- parser `elseThrow` errMsg
  safeLookahead >>= \case
    Just c
      | c == sepChar ->
          (res :) <$> (char sepChar *> separatedBy parser sepChar errMsg)
    _ -> return [res]

spaces :: Parser String String
spaces =
  safeLookahead >>= \case
    Just c | isWhitespace c -> (:) <$> char c <*> spaces
    _ -> return ""
  where
    isWhitespace c = c == ' ' || c == '\n' || c == '\r' || c == '\t'

jArray :: Parser String JValue
jArray =
  JArray <$> do
    _ <- char '[' <* spaces
    c <- lookahead `elseThrow` "Expected a JSON value or ']'"
    case c of
      ']' -> [] <$ char ']'
      _ ->
        separatedBy jValue ',' "Expected a JSON value"
          <* satisfy (== ']') "Expected ',' or ']'"

prop_genParseJArray :: Property
prop_genParseJArray =
  forAllShrink (sized jArrayGen) shrink $ \ja -> do
    jas <- dropWhile isSpace <$> stringify ja
    return . counterexample (show jas) $ case runParser jArray jas of
      Error _ -> False
      Result (_, o) -> o == ja

jObject :: Parser String JValue
jObject =
  JObject <$> do
    _ <- char '{' <* spaces
    c <- lookahead `elseThrow` "Expected a JSON value or '}'"
    case c of
      '}' -> [] <$ char '}'
      _ ->
        separatedBy pair ',' "Expected an object key-value pair"
          <* satisfy (== '}') "Expected ',' or '}'"
  where
    pair = (\ ~(JString s) j -> (s, j)) <$> key <* char ':' <*> value
    key = (jString `surroundedBy` spaces) `elseThrow` "Expected an object key"
    value = jValue `elseThrow` "Expected an object value"

prop_genParseJObject :: Property
prop_genParseJObject =
  forAllShrink (sized jObjectGen) shrink $ \jo -> do
    jos <- dropWhile isSpace <$> stringify jo
    return . counterexample (show jos) $ case runParser jObject jos of
      Error _ -> False
      Result (_, o) -> o == jo

jValue :: Parser String JValue
jValue = jValue' `surroundedBy` spaces
  where
    jValue' =
      lookahead >>= \case
        'n' -> jNull `elseThrow` "Expected null"
        't' -> jBool `elseThrow` "Expected true"
        'f' -> jBool `elseThrow` "Expected false"
        '\"' -> jString `elseThrow` "Expected a string"
        '[' -> jArray `elseThrow` "Expected an array"
        '{' -> jObject `elseThrow` "Expected an object"
        c
          | c == '-' || isDigit c ->
              jNumber `elseThrow` "Expected a number"
        c ->
          throw $
            printf "Unexpected character: '%v'" $
              showCharForErrorMsg c

parseJSON :: String -> Either String JValue
parseJSON s = case runParser jValue s of
  Result ("", j) -> Right j
  Result (i, _) -> Left $ "Leftover input: " <> i
  err@(Error _) -> Left $ show err

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
