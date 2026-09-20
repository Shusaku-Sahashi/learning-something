-- Example 73: tabulate で表を作る
--
-- classify は「条件を満たしたか」の1ビットですが、
-- tabulate は任意の文字列を、名前付きの表に集計できます。
--
-- 実行: runghc Example73.hs
module Main (main) where

import Data.Char (isDigit, isAlpha, isSpace)
import Test.QuickCheck

-- tabulate :: Testable prop => String -> [String] -> prop -> Property
--   第1引数: 表の名前
--   第2引数: この入力から記録したい項目たち (複数可)

------------------------------------------------------------
-- 例1: リストの各要素の符号を集計する
------------------------------------------------------------
prop_elementSigns :: [Int] -> Property
prop_elementSigns xs =
  tabulate "element signs" (map signName xs) $
    length xs >= 0
  where
    signName n | n < 0     = "negative"
               | n == 0    = "zero"
               | otherwise = "positive"

------------------------------------------------------------
-- 例2: 文字列の文字種を集計する
------------------------------------------------------------
prop_charClasses :: String -> Property
prop_charClasses s =
  tabulate "character classes" (map charClass s) $
    length s >= 0
  where
    charClass c
      | isDigit c = "digit"
      | isAlpha c = "letter"
      | isSpace c = "space"
      | otherwise = "other"

------------------------------------------------------------
-- 例3: 複数の表を同時に作る
------------------------------------------------------------
data Event
  = Click Int Int
  | KeyPress Char
  | Scroll Int
  | Resize Int Int
  deriving (Show)

instance Arbitrary Event where
  arbitrary = frequency
    [ (5, Click <$> choose (0, 1920) <*> choose (0, 1080))
    , (3, KeyPress <$> elements (['a' .. 'z'] ++ ['0' .. '9']))
    , (2, Scroll <$> choose (-100, 100))
    , (1, Resize <$> choose (320, 3840) <*> choose (240, 2160))
    ]

eventName :: Event -> String
eventName (Click _ _)  = "Click"
eventName (KeyPress _) = "KeyPress"
eventName (Scroll _)   = "Scroll"
eventName (Resize _ _) = "Resize"

handle :: Event -> String
handle e = eventName e ++ " handled"

prop_eventStream :: [Event] -> Property
prop_eventStream es =
  tabulate "event types" (map eventName es) $
  tabulate "stream length" [lengthBucket (length es)] $
    all (not . null . handle) es
  where
    lengthBucket n
      | n == 0   = "0"
      | n <= 5   = "1-5"
      | n <= 20  = "6-20"
      | otherwise = "21+"

------------------------------------------------------------
-- 例4: 遷移の集計 (連続するペアを記録する)
------------------------------------------------------------
prop_transitions :: [Event] -> Property
prop_transitions es =
  tabulate "transitions" (zipWith trans es (drop 1 es)) $
    length es >= 0
  where
    trans a b = eventName a ++ " -> " ++ eventName b

main :: IO ()
main = do
  putStrLn "--- element signs ---"
  quickCheckWith stdArgs { maxSuccess = 200 } prop_elementSigns
  putStrLn ""

  putStrLn "--- character classes in random Strings ---"
  quickCheckWith stdArgs { maxSuccess = 200 } prop_charClasses
  putStrLn ""

  putStrLn "--- event streams: two tables at once ---"
  quickCheckWith stdArgs { maxSuccess = 500 } prop_eventStream
  putStrLn ""

  putStrLn "--- transitions between consecutive events ---"
  quickCheckWith stdArgs { maxSuccess = 500 } prop_transitions

-- tabulate の強み:
--   1件の入力から複数の項目を記録できること。
--   classify だと「このリストは負の数を含むか」しか言えませんが、
--   tabulate なら「全要素のうち何%が負か」が分かります。
--
-- ★ 上の character classes の結果に注目してください。
--   QuickCheck が生成する String は、記号や制御文字が
--   かなりの割合を占めます。
--   「文字列のテスト」と言いながら、英数字がほとんど来ていない、
--   ということがよくあります。
--
-- ★ transitions の表も有用です。
--   状態遷移のテストで「この遷移は一度も試していない」を発見できます。
--   Ch8 のモデルベーステストと組み合わせると強力です。
