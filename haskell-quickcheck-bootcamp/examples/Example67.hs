-- Example 67: リファクタ実例「条件だらけのテストを直す」
--
-- 実際にありがちな「悪い」テストを、段階的に良くしていきます。
--
-- 実行: runghc Example67.hs
module Main (main) where

import Data.List (sort)
import Test.QuickCheck

------------------------------------------------------------
-- 題材: 割引計算
------------------------------------------------------------
data Order = Order
  { items     :: [(String, Int, Int)]   -- (商品名, 単価, 個数)
  , couponPct :: Int                    -- 割引率 0..50
  }
  deriving (Show, Eq)

subtotal :: Order -> Int
subtotal o = sum [ p * q | (_, p, q) <- items o ]

discountAmount :: Order -> Int
discountAmount o = subtotal o * couponPct o `div` 100

payable :: Order -> Int
payable o = subtotal o - discountAmount o

------------------------------------------------------------
-- Step 0: 素朴な Arbitrary (何でもあり)
------------------------------------------------------------
newtype RawOrder = RawOrder Order
  deriving (Show)

instance Arbitrary RawOrder where
  arbitrary = RawOrder <$> (Order <$> arbitrary <*> arbitrary)

-- 条件を全部 (==>) で書く。読みにくく、大量に捨てる。
prop_v0 :: RawOrder -> Property
prop_v0 (RawOrder o) =
  all (\(_, p, q) -> p > 0 && q > 0) (items o)
    && couponPct o >= 0
    && couponPct o <= 50
    && not (null (items o))
    ==> payable o <= subtotal o && payable o >= 0

------------------------------------------------------------
-- Step 1: 標準 Modifier で書ける部分を置き換える
------------------------------------------------------------
-- 個数と単価は Positive、items は NonEmptyList にできます。
newtype Step1Order = Step1Order Order
  deriving (Show)

instance Arbitrary Step1Order where
  arbitrary = do
    NonEmpty raw <- arbitrary
    let its = [ (n, getPositive p, getPositive q) | (n, p, q) <- raw ]
    pct <- arbitrary
    pure (Step1Order (Order its pct))

prop_v1 :: Step1Order -> Property
prop_v1 (Step1Order o) =
  couponPct o >= 0 && couponPct o <= 50
    ==> payable o <= subtotal o && payable o >= 0

------------------------------------------------------------
-- Step 2: 残った条件も生成器に移す (捨てる入力をゼロにする)
------------------------------------------------------------
newtype ValidOrder = ValidOrder Order
  deriving (Show)

genItem :: Gen (String, Int, Int)
genItem = do
  name  <- listOf1 (elements ['a' .. 'z'])
  price <- choose (1, 100000)
  qty   <- choose (1, 100)
  pure (name, price, qty)

instance Arbitrary ValidOrder where
  arbitrary = do
    n   <- choose (1, 10)
    its <- vectorOf n genItem
    pct <- choose (0, 50)
    pure (ValidOrder (Order its pct))
  -- 縮小も不変条件を守る (Ch5)
  shrink (ValidOrder o) =
    [ ValidOrder o { items = its }
    | its <- shrink (items o)
    , not (null its)
    ] ++
    [ ValidOrder o { couponPct = pct }
    | pct <- shrink (couponPct o)
    , pct >= 0, pct <= 50
    ]

prop_v2_payableBounded :: ValidOrder -> Property
prop_v2_payableBounded (ValidOrder o) =
  counterexample ("subtotal=" ++ show (subtotal o) ++ " payable=" ++ show (payable o))
    (payable o <= subtotal o && payable o >= 0)

-- 生成器を直すと、もっと細かい性質も書けるようになります。
prop_v2_noCouponMeansFullPrice :: ValidOrder -> Property
prop_v2_noCouponMeansFullPrice (ValidOrder o) =
  payable o { couponPct = 0 } === subtotal o

prop_v2_moreCouponIsCheaper :: ValidOrder -> Property
prop_v2_moreCouponIsCheaper (ValidOrder o) =
  forAll (choose (0, 50)) $ \a ->
    forAll (choose (0, 50)) $ \b ->
      a <= b ==> payable o { couponPct = a } >= payable o { couponPct = b }

prop_v2_addingItemRaisesSubtotal :: ValidOrder -> Property
prop_v2_addingItemRaisesSubtotal (ValidOrder o) =
  forAll genItem $ \it ->
    subtotal o { items = it : items o } > subtotal o

------------------------------------------------------------
-- 比較のための測定
------------------------------------------------------------
countDiscards :: Testable p => p -> IO String
countDiscards p = do
  r <- quickCheckWithResult stdArgs { chatty = False } p
  pure (case r of
          Success { numTests = n, numDiscarded = d } ->
            "passed " ++ show n ++ ", discarded " ++ show d
          GaveUp { numTests = n, numDiscarded = d } ->
            "GAVE UP after " ++ show n ++ ", discarded " ++ show d
          Failure { numTests = n } -> "FAILED after " ++ show n
          _ -> "other")

main :: IO ()
main = do
  putStrLn "--- Step 0: everything as a precondition ---"
  s0 <- countDiscards prop_v0
  putStrLn ("  " ++ s0)

  putStrLn "--- Step 1: standard modifiers for what they cover ---"
  s1 <- countDiscards prop_v1
  putStrLn ("  " ++ s1)

  putStrLn "--- Step 2: everything moved into the generator ---"
  s2 <- countDiscards prop_v2_payableBounded
  putStrLn ("  " ++ s2)
  putStrLn ""

  putStrLn "--- sample orders from the Step 2 generator ---"
  os <- sample' (arbitrary :: Gen ValidOrder)
  mapM_ print (take 3 os)
  putStrLn ""

  putStrLn "--- the extra properties Step 2 made possible ---"
  putStr "payable bounded       : " >> quickCheck prop_v2_payableBounded
  putStr "no coupon = full price: " >> quickCheck prop_v2_noCouponMeansFullPrice
  putStr "more coupon, cheaper  : " >> quickCheck prop_v2_moreCouponIsCheaper
  putStr "adding item raises sum: " >> quickCheck prop_v2_addingItemRaisesSubtotal

-- リファクタの手順 (そのまま実務で使えます):
--
--   1. まず動くテストを (==>) で書く。速度は気にしない。
--   2. 標準 Modifier で置き換えられる条件を置き換える。
--   3. 残った条件を生成器に移す。専用の newtype を作る。
--   4. shrink も書く。不変条件を守るように。
--   5. 捨てる数が 0 になったことを確認する。
--   6. そこで初めて、細かい性質を書き足していく。
--
-- 5 まで行かないと 6 に進めません。
-- 捨てる数が多いままだと、性質を増やすたびにテストが遅くなるからです。
