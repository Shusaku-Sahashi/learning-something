-- Example 72: label と classify
--
-- collect は「値」をそのまま記録しますが、
-- label と classify は「名前をつけた条件」を記録します。
--
-- 実行: runghc Example72.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- label :: String -> prop -> Property
--   常にそのラベルを記録する。collect の文字列版。
------------------------------------------------------------
prop_label :: [Int] -> Property
prop_label xs = label (sizeLabel xs) (reverse (reverse xs) == xs)
  where
    sizeLabel ys
      | null ys        = "empty"
      | length ys < 10 = "small"
      | otherwise      = "large"

------------------------------------------------------------
-- classify :: Bool -> String -> prop -> Property
--   条件が真のときだけラベルを記録する。
--   「何パーセントがこの条件を満たしたか」が分かる。
------------------------------------------------------------
prop_classify :: [Int] -> Property
prop_classify xs =
  classify (null xs)            "empty"        $
  classify (length xs == 1)     "singleton"    $
  classify (length xs > 10)     "long (>10)"   $
  classify (all (>= 0) xs)      "all non-negative" $
    reverse (reverse xs) == xs

------------------------------------------------------------
-- 実務的な例: 分岐がすべて通っているか確かめる
------------------------------------------------------------
data Plan = Free | Basic | Pro
  deriving (Show, Eq, Enum, Bounded)

instance Arbitrary Plan where
  arbitrary = frequency [ (6, pure Free), (3, pure Basic), (1, pure Pro) ]

monthlyFee :: Plan -> Int -> Int
monthlyFee Free  _     = 0
monthlyFee Basic users = 500 * max 1 users
monthlyFee Pro   users
  | users <= 10 = 5000
  | otherwise   = 5000 + 300 * (users - 10)

prop_feeNonNegative :: Plan -> NonNegative Int -> Property
prop_feeNonNegative p (NonNegative users) =
  classify (p == Free)             "plan: Free"  $
  classify (p == Basic)            "plan: Basic" $
  classify (p == Pro)              "plan: Pro"   $
  classify (p == Pro && users > 10) "Pro, over 10 users (the tricky branch)" $
  classify (users == 0)            "zero users"  $
    monthlyFee p users >= 0

------------------------------------------------------------
-- label と classify の違い
------------------------------------------------------------
-- label    : 常に記録する。合計が 100% になる。
-- classify : 条件が真のときだけ記録する。合計は 100% を超えることも下回ることもある。
prop_labelVsClassify :: Int -> Property
prop_labelVsClassify n =
  label (if even n then "even" else "odd") (n == n)

prop_classifyOverlap :: Int -> Property
prop_classifyOverlap n =
  classify (even n)   "even"        $
  classify (n > 0)    "positive"    $
  classify (abs n < 5) "small"      $
    n == n

main :: IO ()
main = do
  putStrLn "--- label (always recorded, sums to 100%) ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_label
  putStrLn ""

  putStrLn "--- classify (only when true) ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_classify
  putStrLn ""

  putStrLn "--- checking that every branch is exercised ---"
  quickCheckWith stdArgs { maxSuccess = 2000 } prop_feeNonNegative
  putStrLn ""

  putStrLn "--- label: percentages add up to 100 ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_labelVsClassify
  putStrLn ""

  putStrLn "--- classify: percentages overlap and do not add up ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_classifyOverlap

-- 使いどころ:
--
--   label     入力を排他的なカテゴリに分けたいとき
--             (「空 / 小 / 大」のように、必ずどれか1つ)
--
--   classify  「この条件を何%が満たしたか」を知りたいとき
--             (条件同士が重なっていてよい)
--
--   collect   値そのものの分布を見たいとき
--
-- 一番よく使うのは classify です。
-- 「この分岐に到達しているか?」を確かめる用途が圧倒的に多いからです。
--
-- ★ 上の prop_feeNonNegative の結果を見てください。
--   "Pro, over 10 users" が数パーセントしかありません。
--   一番バグが出やすい分岐なのに、ほとんど試されていません。
--   これを機械的に検出する方法が cover です (Example 74)。
