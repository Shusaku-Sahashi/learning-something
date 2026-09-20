-- Example 76: coverTable で表全体のカバレッジを保証する
--
-- cover は1つのラベルに対する下限でした。
-- coverTable は tabulate の表に対して、複数の下限をまとめて指定します。
--
-- 実行: runghc Example76.hs
module Main (main) where

import Test.QuickCheck

-- coverTable :: Testable prop => String -> [(String, Double)] -> prop -> Property
--   第1引数: 表の名前 (tabulate と対応させる)
--   第2引数: (ラベル, 最低割合) のリスト

data Suit = Hearts | Diamonds | Clubs | Spades
  deriving (Show, Eq, Enum, Bounded)

data Card = Card { rank :: Int, suit :: Suit }
  deriving (Show, Eq)

-- 公平なデッキ
genFairCard :: Gen Card
genFairCard = Card <$> choose (1, 13) <*> elements [minBound .. maxBound]

-- いかさまデッキ (スペードが出にくい)
genRiggedCard :: Gen Card
genRiggedCard = Card
  <$> choose (1, 13)
  <*> frequency [ (10, pure Hearts), (10, pure Diamonds), (9, pure Clubs), (1, pure Spades) ]

score :: Card -> Int
score c = rank c * suitBonus (suit c)
  where
    suitBonus Spades   = 4
    suitBonus Hearts   = 3
    suitBonus Diamonds = 2
    suitBonus Clubs    = 1

------------------------------------------------------------
-- coverTable でスートの分布を保証する
------------------------------------------------------------
suitCoverage :: Gen Card -> Property
suitCoverage gen =
  checkCoverage $
  forAll gen $ \c ->
    tabulate "suits" [show (suit c)] $
    coverTable "suits" [ ("Hearts", 20), ("Diamonds", 20), ("Clubs", 20), ("Spades", 20) ] $
      score c > 0

------------------------------------------------------------
-- ランクの分布も同時に保証する
------------------------------------------------------------
rankBucket :: Int -> String
rankBucket r
  | r == 1            = "ace"
  | r <= 10           = "number"
  | otherwise         = "face"

fullCoverage :: Gen Card -> Property
fullCoverage gen =
  checkCoverage $
  forAll gen $ \c ->
    tabulate "suits" [show (suit c)] $
    tabulate "ranks" [rankBucket (rank c)] $
    coverTable "suits" [ (show s, 20) | s <- [minBound .. maxBound :: Suit] ] $
    coverTable "ranks" [ ("ace", 5), ("number", 60), ("face", 15) ] $
      score c > 0

main :: IO ()
main = do
  putStrLn "--- fair deck: the table meets every target ---"
  quickCheck (suitCoverage genFairCard)
  putStrLn ""

  putStrLn "--- rigged deck: Spades is short, so this FAILS ---"
  quickCheck (suitCoverage genRiggedCard)
  putStrLn ""

  putStrLn "--- two tables guarded at once (fair deck) ---"
  quickCheck (fullCoverage genFairCard)

-- cover と coverTable の使い分け:
--
--   cover      「この条件が n% 以上」を1つずつ書く。条件が重なってよい。
--   coverTable 「この表の各ラベルが n% 以上」をまとめて書く。
--              tabulate の表と対応させる必要がある。
--
-- coverTable が向いているのは:
--   * 列挙型の全ケースを網羅したいとき (上のスート)
--   * 「カテゴリ分け」が排他的なとき
--   * ラベルの数が多いとき (cover を10個並べるより読みやすい)
--
-- 注意:
--   coverTable のラベル名は、tabulate で記録した文字列と
--   完全に一致していなければなりません。
--   タイプミスすると「0% だ」と言われて落ちます。
--   上のように show や関数で生成すると、ミスを防げます。
