-- Example 64: discard を直接使う
--
-- (==>) は「Bool で条件を書く」形でした。
-- もっと細かく制御したいときは discard を使います。
--
-- 実行: runghc Example64.hs
module Main (main) where

import Test.QuickCheck

-- discard :: a
--   「この入力は捨てる」ことを表す値。どんな型としても使えます。
--   (内部的には特別な例外を投げています)

------------------------------------------------------------
-- 使い方1: パターンマッチの中で捨てる
------------------------------------------------------------
-- (==>) だと「条件を Bool で書く」必要がありますが、
-- パターンマッチで分岐したい場合は discard のほうが自然です。
safeDivide :: Int -> Int -> Maybe Int
safeDivide _ 0 = Nothing
safeDivide x y = Just (x `div` y)

prop_divideResult :: Int -> Int -> Property
prop_divideResult x y =
  case safeDivide x y of
    Nothing -> discard                       -- 割れない入力は捨てる
    Just q  -> property (q * y + (x `mod` y) == x)

-- 同じことを (==>) で書くと、条件を2回書くことになります。
prop_divideResultWithImplies :: Int -> Int -> Property
prop_divideResultWithImplies x y =
  y /= 0 ==> case safeDivide x y of
    Nothing -> property False
    Just q  -> property (q * y + (x `mod` y) == x)

------------------------------------------------------------
-- 使い方2: 計算の途中で捨てる
------------------------------------------------------------
-- パースに成功した入力だけでテストしたい
parseIntish :: String -> Maybe Int
parseIntish s = case reads s of
  [(n, "")] -> Just n
  _         -> Nothing

prop_parseThenShow :: String -> Property
prop_parseThenShow s =
  case parseIntish s of
    Nothing -> discard
    Just n  -> parseIntish (show n) === Just n

------------------------------------------------------------
-- 使い方3: 「捨てる」を関数に切り出す
------------------------------------------------------------
-- 前提条件が複雑なときは、Maybe を返す関数に切り出すと読みやすくなります。
data Order = Order { qty :: Int, unitPrice :: Int }
  deriving (Show)

instance Arbitrary Order where
  arbitrary = Order <$> arbitrary <*> arbitrary

-- 「有効な注文」に正規化できるなら Just、できないなら Nothing
toValidOrder :: Order -> Maybe Order
toValidOrder o
  | qty o <= 0           = Nothing
  | unitPrice o <= 0     = Nothing
  | qty o > 1000         = Nothing
  | otherwise            = Just o

total_ :: Order -> Int
total_ o = qty o * unitPrice o

prop_totalPositive :: Order -> Property
prop_totalPositive o = case toValidOrder o of
  Nothing -> discard
  Just v  -> property (total_ v > 0)

-- ★ ただし、この書き方も「捨てすぎ」の問題からは逃れられません。
--   ほとんどの Order が無効なので、大量に捨てることになります。
--   正しくは「有効な Order を生成する」ことです。
newtype ValidOrder = ValidOrder Order
  deriving (Show)

instance Arbitrary ValidOrder where
  arbitrary = ValidOrder <$> (Order <$> choose (1, 1000) <*> choose (1, 100000))

prop_totalPositiveGenerated :: ValidOrder -> Bool
prop_totalPositiveGenerated (ValidOrder o) = total_ o > 0

main :: IO ()
main = do
  putStr "divide (discard)    : " >> quickCheck prop_divideResult
  putStr "divide ((==>))      : " >> quickCheck prop_divideResultWithImplies
  putStrLn ""

  putStrLn "--- parse: almost everything is discarded ---"
  quickCheck prop_parseThenShow
  putStrLn ""

  putStrLn "--- order with discard ---"
  quickCheck prop_totalPositive
  putStrLn ""

  putStrLn "--- order with a proper generator ---"
  quickCheck prop_totalPositiveGenerated

-- discard と (==>) の使い分け:
--
--   (==>)    条件が単純な Bool で書ける      (推奨。読みやすい)
--   discard  パターンマッチや Maybe で分岐したい
--
-- どちらを使っても「捨てる」という本質は同じです。
-- 捨てる量が多いなら、生成器を直すのが唯一の正解です。
--
-- 上の prop_parseThenShow の実行結果を見てください。
-- ランダムな String がパースできることは滅多にないので、
-- ほとんど Gave up します。
-- 「数字の文字列」を生成すれば一発で解決します (Example 36 の NumericString)。
