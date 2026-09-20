-- Example 98: アンチパターン集
--
-- よくある「効かないプロパティ」を並べます。
-- どれも実際に書かれているものです。自分のテストと見比べてください。
--
-- 実行: runghc Example98.hs
module Main (main) where

import Data.List (sort)
import Test.QuickCheck

------------------------------------------------------------
-- アンチパターン1: 実装をそのまま書き写す
------------------------------------------------------------
-- 「テスト対象と同じ式」を書いても、何も検査していません。
-- バグがあれば、両方に同じバグが入ります。
discountPrice :: Int -> Int -> Int
discountPrice price pct = price - (price * pct `div` 100)

prop_bad_reimplementation :: Positive Int -> Property
prop_bad_reimplementation (Positive price) =
  forAll (choose (0, 100)) $ \pct ->
    discountPrice price pct === price - (price * pct `div` 100)   -- ★ 同じ式

-- 良い書き方: 「性質」を書く
prop_good_discountBounds :: Positive Int -> Property
prop_good_discountBounds (Positive price) =
  forAll (choose (0, 100)) $ \pct ->
    let p = discountPrice price pct
    in counterexample (show p) (p >= 0 .&&. p <= price)

prop_good_discountMonotone :: Positive Int -> Property
prop_good_discountMonotone (Positive price) =
  forAll (choose (0, 100)) $ \a ->
  forAll (choose (0, 100)) $ \b ->
    a <= b ==> discountPrice price a >= discountPrice price b

prop_good_zeroPercent :: Positive Int -> Property
prop_good_zeroPercent (Positive price) = discountPrice price 0 === price

------------------------------------------------------------
-- アンチパターン2: トートロジー (常に真)
------------------------------------------------------------
-- 見た目はプロパティですが、どんな実装でも成り立ちます。
prop_bad_tautology :: [Int] -> Bool
prop_bad_tautology xs = length (sort xs) >= 0        -- 長さは常に 0 以上

prop_bad_tautology2 :: Int -> Bool
prop_bad_tautology2 x = x == x                       -- 当たり前

-- 見分け方: 「テスト対象を undefined に置き換えても通るか?」
--   通るなら、そのプロパティは何も検査していません。

------------------------------------------------------------
-- アンチパターン3: 条件が厳しすぎて実質実行されていない
------------------------------------------------------------
prop_bad_neverRuns :: [Int] -> Property
prop_bad_neverRuns xs =
  length xs > 30 && sum xs == 0 ==> sort xs == sort xs

-- Gave up するか、ごく少数しか実行されません。
-- 「通った」と表示されても、実際は数件しか試していないことがあります。

------------------------------------------------------------
-- アンチパターン4: 生成器が偏っていて分岐に届かない
------------------------------------------------------------
data Payment = Cash | Card String | Points Int
  deriving (Show, Eq)

fee :: Payment -> Int
fee Cash       = 0
fee (Card _)   = 30
fee (Points n) = if n > 1000 then 0 else 10

-- 悪い生成器: Cash しか作らない
genPaymentBad :: Gen Payment
genPaymentBad = pure Cash

prop_bad_generator :: Property
prop_bad_generator = forAll genPaymentBad (\p -> fee p >= 0)

-- 良い生成器 + カバレッジで固定
genPaymentGood :: Gen Payment
genPaymentGood = frequency
  [ (3, pure Cash)
  , (3, Card <$> vectorOf 4 (elements ['0' .. '9']))
  , (2, Points <$> choose (0, 1000))
  , (2, Points <$> choose (1001, 100000))
  ]

prop_good_generator :: Property
prop_good_generator =
  checkCoverage $
  forAll genPaymentGood $ \p ->
    cover 20 (p == Cash)                "cash"          $
    cover 20 (isCard p)                 "card"          $
    cover 15 (isSmallPoints p)          "points <= 1000" $
    cover 15 (isBigPoints p)            "points > 1000"  $
      fee p >= 0
  where
    isCard (Card _) = True
    isCard _        = False
    isSmallPoints (Points n) = n <= 1000
    isSmallPoints _          = False
    isBigPoints (Points n) = n > 1000
    isBigPoints _          = False

------------------------------------------------------------
-- アンチパターン5: shrink を書かないまま複雑な型を使う
------------------------------------------------------------
data Config = Config Int Int Int Int Int
  deriving (Show, Eq)

newtype NoShrinkConfig = NoShrinkConfig Config deriving (Show)

instance Arbitrary NoShrinkConfig where
  arbitrary = NoShrinkConfig <$>
    (Config <$> choose (0, 999) <*> choose (0, 999) <*> choose (0, 999)
            <*> choose (0, 999) <*> choose (0, 999))

newtype ShrinkConfig = ShrinkConfig Config deriving (Show)

instance Arbitrary ShrinkConfig where
  arbitrary = ShrinkConfig <$>
    (Config <$> choose (0, 999) <*> choose (0, 999) <*> choose (0, 999)
            <*> choose (0, 999) <*> choose (0, 999))
  shrink (ShrinkConfig (Config a b c d e)) =
    [ ShrinkConfig (Config a' b' c' d' e')
    | (a', b', c', d', e') <- shrink (a, b, c, d, e)
    ]

prop_bad_noShrink :: NoShrinkConfig -> Bool
prop_bad_noShrink (NoShrinkConfig (Config a b c d e)) = a + b + c + d + e < 100

prop_good_withShrink :: ShrinkConfig -> Bool
prop_good_withShrink (ShrinkConfig (Config a b c d e)) = a + b + c + d + e < 100

------------------------------------------------------------
-- アンチパターン6: 失敗しても情報がない
------------------------------------------------------------
prop_bad_noInfo :: [Int] -> Bool
prop_bad_noInfo xs = complicated xs == expected xs
  where
    complicated = map (* 2) . filter even
    expected    = map (* 2) . filter (\x -> x `mod` 2 == 1)   -- わざと違う

prop_good_withInfo :: [Int] -> Property
prop_good_withInfo xs =
  counterexample ("input    = " ++ show xs) $
  counterexample ("actual   = " ++ show (complicated xs)) $
  counterexample ("expected = " ++ show (expected xs)) $
    complicated xs === expected xs
  where
    complicated = map (* 2) . filter even
    expected    = map (* 2) . filter (\x -> x `mod` 2 == 1)

main :: IO ()
main = do
  putStrLn "--- 1. reimplementing the code under test ---"
  putStr "  bad  (passes, tests nothing) : " >> quickCheck prop_bad_reimplementation
  putStr "  good (bounds)                : " >> quickCheck prop_good_discountBounds
  putStr "  good (monotone)              : " >> quickCheck prop_good_discountMonotone
  putStr "  good (zero percent)          : " >> quickCheck prop_good_zeroPercent
  putStrLn ""

  putStrLn "--- 2. tautologies ---"
  putStr "  length >= 0                  : " >> quickCheck prop_bad_tautology
  putStr "  x == x                       : " >> quickCheck prop_bad_tautology2
  putStrLn "  ^ both pass. Both are useless."
  putStrLn ""

  putStrLn "--- 3. a precondition that is almost never satisfied ---"
  quickCheck prop_bad_neverRuns
  putStrLn ""

  putStrLn "--- 4. a generator that never reaches the interesting branches ---"
  putStr "  bad  : " >> quickCheck prop_bad_generator
  putStrLn "  ^ passes, but only Cash was ever tried"
  putStr "  good : " >> quickCheck prop_good_generator
  putStrLn ""

  putStrLn "--- 5. no shrink: the counterexample is unreadable ---"
  quickCheck prop_bad_noShrink
  putStrLn "  with shrink:"
  quickCheck prop_good_withShrink
  putStrLn ""

  putStrLn "--- 6. a failure with no context ---"
  quickCheck prop_bad_noInfo
  putStrLn "  with counterexample:"
  quickCheck prop_good_withInfo

-- 自己点検のチェックリスト:
--
--   [ ] テスト対象を undefined に置き換えたら、このプロパティは落ちるか?
--   [ ] 実装をわざと壊したら、このプロパティは落ちるか?
--   [ ] discarded の数はゼロに近いか?
--   [ ] classify で見て、狙った分岐に届いているか?
--   [ ] 反例は読める大きさまで縮んでいるか?
--   [ ] 反例を見て、原因の見当がつくか?
--
-- 1つでも「いいえ」があるなら、そのプロパティは直す価値があります。
