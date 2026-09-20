-- Example 38: 実例「日付の生成器」
--
-- 日付はバグの温床です。うるう年、月末、月をまたぐ加算。
-- 生成器を丁寧に書くと、こういうバグがざくざく出てきます。
--
-- (標準の time パッケージを使わず、自前で実装します。
--  そのほうが「何をテストしているか」がはっきりするためです)
--
-- 実行: runghc Example38.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 日付の型
------------------------------------------------------------
data Date = Date { year :: Int, month :: Int, day :: Int }
  deriving (Eq, Ord)

instance Show Date where
  show (Date y m d) = pad 4 y ++ "-" ++ pad 2 m ++ "-" ++ pad 2 d
    where pad n v = let s = show v in replicate (n - length s) '0' ++ s

isLeapYear :: Int -> Bool
isLeapYear y = (y `mod` 4 == 0 && y `mod` 100 /= 0) || y `mod` 400 == 0

daysInMonth :: Int -> Int -> Int
daysInMonth y m
  | m == 2                     = if isLeapYear y then 29 else 28
  | m `elem` [4, 6, 9, 11]     = 30
  | otherwise                  = 31

validDate :: Date -> Bool
validDate (Date y m d) =
  m >= 1 && m <= 12 && d >= 1 && d <= daysInMonth y m

------------------------------------------------------------
-- 生成器: 正しい日付だけを作る
------------------------------------------------------------
instance Arbitrary Date where
  arbitrary = do
    y <- choose (1900, 2100)
    m <- choose (1, 12)
    d <- choose (1, daysInMonth y m)   -- 月と年に依存するので do が必要
    pure (Date y m d)

-- 特殊な日付を狙い撃ちする生成器
newtype LeapDay = LeapDay Date deriving (Show)

instance Arbitrary LeapDay where
  arbitrary = do
    y <- choose (1900, 2100) `suchThat` isLeapYear
    pure (LeapDay (Date y 2 29))

newtype MonthEnd = MonthEnd Date deriving (Show)

instance Arbitrary MonthEnd where
  arbitrary = do
    y <- choose (1900, 2100)
    m <- choose (1, 12)
    pure (MonthEnd (Date y m (daysInMonth y m)))

------------------------------------------------------------
-- テスト対象: 日付に1日足す (バグあり版と修正版)
------------------------------------------------------------
-- バグ版: 月末の処理を忘れている
nextDayBuggy :: Date -> Date
nextDayBuggy (Date y m d) = Date y m (d + 1)

-- 修正版
nextDay :: Date -> Date
nextDay (Date y m d)
  | d < daysInMonth y m = Date y m (d + 1)
  | m < 12              = Date y (m + 1) 1
  | otherwise           = Date (y + 1) 1 1

-- 月を足す (よくあるバグ: 1/31 に1ヶ月足すと 2/31 になる)
addMonthBuggy :: Date -> Date
addMonthBuggy (Date y m d)
  | m < 12    = Date y (m + 1) d
  | otherwise = Date (y + 1) 1 d

addMonth :: Date -> Date
addMonth (Date y m d) =
  let (y', m') = if m < 12 then (y, m + 1) else (y + 1, 1)
  in Date y' m' (min d (daysInMonth y' m'))

------------------------------------------------------------
-- プロパティ
------------------------------------------------------------
prop_generatorMakesValidDates :: Date -> Bool
prop_generatorMakesValidDates = validDate

prop_nextDayValid :: Date -> Property
prop_nextDayValid d =
  counterexample ("nextDay " ++ show d ++ " = " ++ show (nextDay d))
    (validDate (nextDay d))

prop_nextDayBuggyValid :: Date -> Property
prop_nextDayBuggyValid d =
  counterexample ("nextDayBuggy " ++ show d ++ " = " ++ show (nextDayBuggy d))
    (validDate (nextDayBuggy d))

prop_nextDayIncreases :: Date -> Bool
prop_nextDayIncreases d = nextDay d > d

prop_addMonthValid :: Date -> Property
prop_addMonthValid d =
  counterexample ("addMonth " ++ show d ++ " = " ++ show (addMonth d))
    (validDate (addMonth d))

prop_addMonthBuggyValid :: Date -> Property
prop_addMonthBuggyValid d =
  counterexample ("addMonthBuggy " ++ show d ++ " = " ++ show (addMonthBuggy d))
    (validDate (addMonthBuggy d))

-- 特殊生成器を使ったプロパティ
prop_leapDayValid :: LeapDay -> Bool
prop_leapDayValid (LeapDay d) = validDate d

prop_monthEndNextDayIsFirst :: MonthEnd -> Property
prop_monthEndNextDayIsFirst (MonthEnd d) = day (nextDay d) === 1

-- 12ヶ月足すと年が1つ進む (日が調整される場合を除く)
prop_twelveMonths :: Date -> Property
prop_twelveMonths d =
  let d12 = iterate addMonth d !! 12
  in day d == day d12 ==> year d12 === year d + 1

main :: IO ()
main = do
  putStrLn "--- generated dates ---"
  ds <- sample' (arbitrary :: Gen Date)
  print (map show ds)

  putStrLn "--- leap days ---"
  ls <- sample' (arbitrary :: Gen LeapDay)
  print (take 5 [ show d | LeapDay d <- ls ])

  putStrLn "--- month ends ---"
  ms <- sample' (arbitrary :: Gen MonthEnd)
  print (take 8 [ show d | MonthEnd d <- ms ])

  putStrLn ""
  putStrLn "--- generator itself ---"
  putStr "valid dates      : " >> quickCheck prop_generatorMakesValidDates
  putStr "leap days valid  : " >> quickCheck prop_leapDayValid

  putStrLn ""
  putStrLn "--- nextDay ---"
  putStr "fixed  valid     : " >> quickCheck prop_nextDayValid
  putStr "fixed  increases : " >> quickCheck prop_nextDayIncreases
  putStrLn "buggy (fails on purpose):"
  quickCheck prop_nextDayBuggyValid
  putStr "month end -> 1st : " >> quickCheck prop_monthEndNextDayIsFirst

  putStrLn ""
  putStrLn "--- addMonth ---"
  putStr "fixed  valid     : " >> quickCheck prop_addMonthValid
  putStrLn "buggy (fails on purpose):"
  quickCheck prop_addMonthBuggyValid
  putStr "12 months = 1yr  : " >> quickCheck prop_twelveMonths

-- 注目点:
--   Date の生成器で d <- choose (1, daysInMonth y m) と書いているところ。
--   日の範囲が年と月に依存するので、Applicative では書けず do が必要です。
--   (Example 28 の「依存する生成」です)
--
--   MonthEnd / LeapDay のような「狙い撃ち生成器」を用意すると、
--   普通の生成では滅多に出ない条件を確実に試せます。
--   2/29 が出る確率は 1/1500 程度です。ランダム任せでは足りません。
