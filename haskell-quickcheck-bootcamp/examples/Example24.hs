-- Example 24: 自分で Gen を作る (1) choose と elements
--
-- Gen a は「a をランダムに作る方法」を表す型です。
-- 一から組み立てるための基本部品を見ていきます。
--
-- 実行: runghc Example24.hs
module Main (main) where

import Test.QuickCheck

-- choose :: Random a => (a, a) -> Gen a
--   閉区間 [lo, hi] から一様に選ぶ。両端を含みます。
genDie :: Gen Int
genDie = choose (1, 6)

genPercent :: Gen Int
genPercent = choose (0, 100)

genLowerLetter :: Gen Char
genLowerLetter = choose ('a', 'z')

-- chooseInt :: (Int, Int) -> Gen Int
--   Int 専用。choose より少し速い。
genDieFast :: Gen Int
genDieFast = chooseInt (1, 6)

-- elements :: [a] -> Gen a
--   リストから一様に1つ選ぶ。リストが空だと実行時エラーになるので注意。
data Suit = Hearts | Diamonds | Clubs | Spades
  deriving (Show, Eq, Enum, Bounded)

genSuit :: Gen Suit
genSuit = elements [Hearts, Diamonds, Clubs, Spades]

-- Bounded + Enum なら [minBound .. maxBound] で書けます。
genSuit2 :: Gen Suit
genSuit2 = elements [minBound .. maxBound]

genHttpMethod :: Gen String
genHttpMethod = elements ["GET", "POST", "PUT", "DELETE", "PATCH"]

-- 組み合わせる: Gen は Monad なので do 記法が使えます (Example 29)
genCard :: Gen (Int, Suit)
genCard = do
  rank <- choose (1, 13)
  suit <- genSuit
  return (rank, suit)

main :: IO ()
main = do
  putStrLn "--- choose (1,6) : a die ---"
  rolls <- sample' genDie
  print rolls

  putStrLn "--- choose (0,100) ---"
  ps <- sample' genPercent
  print ps

  putStrLn "--- choose ('a','z') ---"
  cs <- sample' genLowerLetter
  print cs

  putStrLn "--- chooseInt (1,6) ---"
  rolls2 <- sample' genDieFast
  print rolls2

  putStrLn "--- elements: Suit ---"
  suits <- sample' genSuit
  print suits

  putStrLn "--- elements [minBound..maxBound] ---"
  suits2 <- sample' genSuit2
  print suits2

  putStrLn "--- elements: HTTP method ---"
  ms <- sample' genHttpMethod
  print ms

  putStrLn "--- combined: a playing card ---"
  cards <- sample' genCard
  print cards

  putStrLn ""
  putStrLn "--- using a custom Gen in a property: forAll ---"
  -- forAll :: (Show a, Testable prop) => Gen a -> (a -> prop) -> Property
  --   「Arbitrary インスタンスではなく、この Gen を使え」という指示です。
  quickCheck (forAll genDie (\d -> d >= 1 && d <= 6))
  quickCheck (forAll genCard (\(r, _) -> r >= 1 && r <= 13))

-- ポイント:
--   choose は両端を含む閉区間です。choose (0, 0) は必ず 0 を返します。
--   choose (5, 1) のように lo > hi を渡すと、QuickCheck 2.14 では
--   範囲が入れ替えられて扱われますが、意図が伝わらないので避けましょう。
--
--   elements [] は実行時エラー ("elements used with empty list") です。
--   生成候補が空になりうる場面では、先に空かどうかを判定してください。
