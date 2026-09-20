-- Example 36: newtype ラッパーで生成戦略を切り替える
--
-- 同じ型に対して「別の生成のしかた」を使いたいことがよくあります。
-- Haskell では、型ごとにインスタンスは1つしか書けません。
-- そこで newtype でラップします。QuickCheck 自身もこの方式です (Ch6 の Modifier)。
--
-- 実行: runghc Example36.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- String に対する複数の生成戦略
------------------------------------------------------------
newtype AsciiWord = AsciiWord String
  deriving (Show, Eq)

instance Arbitrary AsciiWord where
  arbitrary = AsciiWord <$> listOf1 (elements (['a' .. 'z'] ++ ['A' .. 'Z']))

newtype NumericString = NumericString String
  deriving (Show, Eq)

instance Arbitrary NumericString where
  arbitrary = NumericString <$> listOf1 (elements ['0' .. '9'])

newtype Whitespacey = Whitespacey String
  deriving (Show, Eq)

instance Arbitrary Whitespacey where
  arbitrary = Whitespacey <$> listOf (elements " \t\n\r")

newtype NastyString = NastyString String
  deriving (Show, Eq)

instance Arbitrary NastyString where
  -- SQL インジェクションやパストラバーサルのような「意地悪な入力」
  arbitrary = NastyString <$> elements
    [ "", " ", "\n", "\0", "'; DROP TABLE users; --"
    , "../../etc/passwd", "<script>alert(1)</script>"
    , "%00", "\255\254", replicate 1000 'a'
    ]

------------------------------------------------------------
-- Int に対する複数の生成戦略
------------------------------------------------------------
newtype SmallNat = SmallNat Int
  deriving (Show, Eq)

instance Arbitrary SmallNat where
  arbitrary = SmallNat <$> choose (0, 20)

newtype Boundary = Boundary Int
  deriving (Show, Eq)

instance Arbitrary Boundary where
  -- 境界値だけを狙い撃ちする生成器
  arbitrary = Boundary <$> elements
    [ minBound, minBound + 1, -1, 0, 1, maxBound - 1, maxBound ]

------------------------------------------------------------
-- 使い方: パターンマッチで中身を取り出す
------------------------------------------------------------
-- テスト対象: 文字列を整数に変換する (簡易版)
parseIntSafe :: String -> Maybe Int
parseIntSafe s = case reads s of
  [(n, "")] -> Just n
  _         -> Nothing

prop_numericParses :: NumericString -> Property
prop_numericParses (NumericString s) =
  -- 数字だけの文字列は必ずパースできる ... と思いきや、
  -- 極端に長いとオーバーフローするので、ここでは長さを絞ります。
  length s <= 9 ==> parseIntSafe s =/= Nothing

prop_wordsDoNotParse :: AsciiWord -> Property
prop_wordsDoNotParse (AsciiWord s) = parseIntSafe s === Nothing

prop_nastyDoesNotCrash :: NastyString -> Property
prop_nastyDoesNotCrash (NastyString s) = total (parseIntSafe s)

prop_smallNatInRange :: SmallNat -> Bool
prop_smallNatInRange (SmallNat n) = n >= 0 && n <= 20

prop_boundaryAbs :: Boundary -> Property
prop_boundaryAbs (Boundary n) =
  -- 境界値生成器を使うと、この「常識的な性質」がすぐ壊れます。
  -- abs minBound は Int のオーバーフローで負のままです。
  counterexample ("abs " ++ show n ++ " = " ++ show (abs n)) (abs n >= 0)

main :: IO ()
main = do
  putStrLn "--- AsciiWord ---"
  a <- sample' (arbitrary :: Gen AsciiWord)
  mapM_ print (take 5 a)

  putStrLn "--- NumericString ---"
  b <- sample' (arbitrary :: Gen NumericString)
  mapM_ print (take 5 b)

  putStrLn "--- Whitespacey ---"
  c <- sample' (arbitrary :: Gen Whitespacey)
  mapM_ print (take 5 c)

  putStrLn "--- NastyString ---"
  d <- sample' (arbitrary :: Gen NastyString)
  mapM_ print (take 4 (map truncateShow d))

  putStrLn "--- Boundary ---"
  e <- sample' (arbitrary :: Gen Boundary)
  print e

  putStrLn ""
  putStrLn "--- properties ---"
  putStr "numeric parses      : " >> quickCheck prop_numericParses
  putStr "words do not parse  : " >> quickCheck prop_wordsDoNotParse
  putStr "nasty does not crash: " >> quickCheck prop_nastyDoesNotCrash
  putStr "small nat in range  : " >> quickCheck prop_smallNatInRange
  putStrLn "boundary abs (fails on purpose):"
  quickCheck prop_boundaryAbs
  where
    truncateShow (NastyString s) =
      NastyString (if length s > 30 then take 30 s ++ "..." else s)

-- ポイント:
--   * newtype は実行時のコストがゼロです。いくらでも作って構いません。
--   * 「この型にこの生成戦略」を名前で表現できるので、テストが読みやすくなります。
--   * Boundary のような「意地悪生成器」を1つ用意しておくと、
--     全プロジェクトで使い回せます。
--
-- QuickCheck 標準の Modifier (Positive, NonEmptyList など) も
-- まったく同じ仕組みです。Ch6 で詳しく見ます。
