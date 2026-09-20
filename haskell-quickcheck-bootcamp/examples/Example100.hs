-- Example 100: 総仕上げ「価格計算エンジンを全部の技で固める」
--
-- Ch1 から Ch9 までの技を、1つの題材に全部適用します。
-- これが終わったら、自分のプロジェクトで同じことをしてください。
--
-- 実行: runghc Example100.hs
{-# LANGUAGE ExistentialQuantification #-}
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- ドメイン
------------------------------------------------------------
data Item = Item
  { itemName  :: String
  , unitPrice :: Int     -- 1円単位。0 以上
  , quantity  :: Int     -- 1 以上
  }
  deriving (Show, Eq)

data Coupon
  = NoCoupon
  | PercentOff Int          -- 0..50 %
  | FlatOff Int             -- 0 以上の円
  | FreeShipping
  deriving (Show, Eq)

data Cart = Cart
  { cartItems  :: [Item]
  , cartCoupon :: Coupon
  , isMember   :: Bool
  }
  deriving (Show, Eq)

data Receipt = Receipt
  { subtotal   :: Int
  , discount   :: Int
  , shipping   :: Int
  , grandTotal :: Int    -- 注: total は Test.QuickCheck の関数と衝突するので改名
  }
  deriving (Show, Eq)

------------------------------------------------------------
-- 計算ロジック
------------------------------------------------------------
shippingFee :: Int -> Bool -> Coupon -> Int
shippingFee sub member coupon
  | coupon == FreeShipping = 0
  | member                 = 0
  | sub >= 5000            = 0
  | sub == 0               = 0
  | otherwise              = 500

couponDiscount :: Int -> Coupon -> Int
couponDiscount sub coupon = case coupon of
  NoCoupon      -> 0
  PercentOff p  -> sub * p `div` 100
  FlatOff n     -> min n sub          -- 小計を超えて引かない
  FreeShipping  -> 0

checkout :: Cart -> Receipt
checkout cart = Receipt
  { subtotal = sub
  , discount = disc
  , shipping = ship
  , grandTotal = sub - disc + ship
  }
  where
    sub  = sum [ unitPrice i * quantity i | i <- cartItems cart ]
    disc = couponDiscount sub (cartCoupon cart)
    ship = shippingFee sub (isMember cart) (cartCoupon cart)

------------------------------------------------------------
-- Ch4: 生成器。不変条件を「構成的に」満たす
------------------------------------------------------------
-- ★ 分布の設計 (Ch7)
--   最初は価格を choose (1, 100000)、個数を choose (1, 50) にしていましたが、
--   小計がすぐ 5000 円を超えてしまい、「送料を払う」分岐が 5% 未満しか
--   出ませんでした (cover が失敗して気づきました)。
--   価格と個数を小さめに寄せて、境界 5000 をまたぐようにしています。
genItem :: Gen Item
genItem = Item
  <$> genName
  <*> frequency [ (6, choose (1, 2000))       -- 普通の価格
                , (2, choose (2001, 8000))
                , (1, pure 0)                 -- 無料品という境界
                , (1, elements [1, 4999, 5000, 5001])  -- 送料無料の境界ぴったり
                ]
  <*> frequency [ (8, choose (1, 3)), (1, choose (4, 10)), (1, pure 1) ]
  where
    genName = do
      n <- choose (1, 8)
      vectorOf n (elements ['a' .. 'z'])

genCoupon :: Gen Coupon
genCoupon = frequency
  [ (4, pure NoCoupon)
  , (3, PercentOff <$> choose (0, 50))
  , (2, FlatOff <$> choose (0, 20000))
  , (1, pure FreeShipping)
  ]

newtype ValidCart = ValidCart Cart
  deriving (Show, Eq)

instance Arbitrary ValidCart where
  arbitrary = do
    n <- frequency [ (1, pure 0), (6, choose (1, 3)), (1, choose (4, 8)) ]
    items <- vectorOf n genItem
    ValidCart <$> (Cart items <$> genCoupon <*> arbitrary)

  -- Ch5: 縮小も不変条件を守る (商品の個数を減らすだけ)
  shrink (ValidCart c) =
    [ ValidCart c { cartItems = its } | its <- shrinkList (const []) (cartItems c) ] ++
    [ ValidCart c { cartCoupon = NoCoupon } | cartCoupon c /= NoCoupon ] ++
    [ ValidCart c { isMember = False } | isMember c ]

validCart :: Cart -> Bool
validCart c =
  all (\i -> unitPrice i >= 0 && quantity i >= 1) (cartItems c)
    && validCoupon (cartCoupon c)
  where
    validCoupon (PercentOff p) = p >= 0 && p <= 50
    validCoupon (FlatOff n)    = n >= 0
    validCoupon _              = True

------------------------------------------------------------
-- 狙い撃ち生成器 (Ch4, Ch7)
------------------------------------------------------------
genCartWithSubtotalNear :: Int -> Gen Cart
genCartWithSubtotalNear target = do
  d <- choose (-200, 200)
  let price = max 0 (target + d)
  coupon <- genCoupon
  member <- arbitrary
  pure (Cart [Item "x" price 1] coupon member)

------------------------------------------------------------
-- プロパティ: 章ごとに整理する
------------------------------------------------------------
data P = forall p. Testable p => P String p

-- Ch4/Ch5: 生成器と縮小
genProps :: [P]
genProps =
  [ P "generator is valid"   (\(ValidCart c) -> validCart c)
  , P "shrink is valid"      (\vc -> all (\(ValidCart c) -> validCart c) (shrink vc))
  , P "shrink is smaller"    (\vc -> (vc :: ValidCart) `notElem` shrink vc)
  ]

-- Ch2: 不変条件
invariantProps :: [P]
invariantProps =
  [ P "total >= 0"
      (\(ValidCart c) -> let r = checkout c
                         in counterexample (show r) (grandTotal r >= 0))
  , P "discount <= subtotal"
      (\(ValidCart c) -> let r = checkout c
                         in counterexample (show r) (discount r <= subtotal r))
  , P "discount >= 0"
      (\(ValidCart c) -> discount (checkout c) >= 0)
  , P "shipping is 0 or 500"
      (\(ValidCart c) -> shipping (checkout c) `elem` [0, 500])
  , P "parts add up"
      (\(ValidCart c) -> let r = checkout c
                         in grandTotal r === subtotal r - discount r + shipping r)
  ]

-- Ch2: メタモルフィック
metamorphicProps :: [P]
metamorphicProps =
  [ P "adding an item never lowers the subtotal"
      (\(ValidCart c) ->
         forAll genItem $ \i ->
           subtotal (checkout c { cartItems = i : cartItems c })
             >= subtotal (checkout c))
  , P "a bigger percent coupon never costs more"
      (\(ValidCart c) ->
         forAll (choose (0, 50)) $ \a ->
         forAll (choose (0, 50)) $ \b ->
           a <= b ==>
             grandTotal (checkout c { cartCoupon = PercentOff a })
               >= grandTotal (checkout c { cartCoupon = PercentOff b }))
  , P "item order does not matter"
      (\(ValidCart c) ->
         checkout c { cartItems = reverse (cartItems c) } === checkout c)
  , P "members never pay more than non-members"
      (\(ValidCart c) ->
         grandTotal (checkout c { isMember = True })
           <= grandTotal (checkout c { isMember = False }))
  ]

-- Ch2: 具体的な仕様
specProps :: [P]
specProps =
  [ P "empty cart is free"
      (once (checkout (Cart [] NoCoupon False) === Receipt 0 0 0 0))
  , P "5000 or more ships free"
      (forAll (genCartWithSubtotalNear 5000) $ \c ->
         subtotal (checkout c) >= 5000 && cartCoupon c /= FreeShipping
           ==> shipping (checkout c) === 0)
  , P "below 5000 pays shipping (non-member, no coupon)"
      (forAll (genCartWithSubtotalNear 5000) $ \c0 ->
         let c = c0 { isMember = False, cartCoupon = NoCoupon }
             s = subtotal (checkout c)
         in s > 0 && s < 5000 ==> shipping (checkout c) === 500)
  , P "FreeShipping always ships free"
      (\(ValidCart c) -> shipping (checkout c { cartCoupon = FreeShipping }) === 0)
  , P "FlatOff never exceeds the subtotal"
      (\(ValidCart c) ->
         forAll (choose (0, 100000)) $ \n ->
           discount (checkout c { cartCoupon = FlatOff n })
             <= subtotal (checkout c))
  , P "NoCoupon gives no discount"
      (\(ValidCart c) -> discount (checkout c { cartCoupon = NoCoupon }) === 0)
  ]

-- Ch7: カバレッジ
coverageProps :: [P]
coverageProps =
  [ P "branches are exercised"
      (checkCoverage $
       forAll (arbitrary :: Gen ValidCart) $ \(ValidCart c) ->
         let r = checkout c in
         -- しきい値は上の実測値のおよそ半分にしてあります。
         -- (実測: empty 12%, pays shipping 13%, free shipping 72%,
         --        discount 41%, member 51%)
         cover 5  (null (cartItems c))       "empty cart"         $
         cover 5  (shipping r == 500)        "pays shipping"      $
         cover 30 (shipping r == 0 && subtotal r > 0) "free shipping" $
         cover 20 (discount r > 0)           "a discount applies" $
         cover 20 (isMember c)               "member"             $
           grandTotal r >= 0)
  , P "coupon types all appear"
      (checkCoverage $
       forAll genCoupon $ \c ->
         tabulate "coupon" [couponName c] $
         coverTable "coupon" [ ("NoCoupon", 25), ("PercentOff", 20)
                             , ("FlatOff", 10), ("FreeShipping", 5) ] $
           True)
  ]

-- 分布を実測するためのプロパティ (しきい値を決める前に、まずこれで測る)
prop_measure :: Property
prop_measure =
  forAll (arbitrary :: Gen ValidCart) $ \(ValidCart c) ->
    let r = checkout c in
    classify (null (cartItems c))                "empty cart"        $
    classify (shipping r == 500)                 "pays shipping"     $
    classify (shipping r == 0 && subtotal r > 0) "free shipping"     $
    classify (discount r > 0)                    "a discount applies" $
    classify (isMember c)                        "member"            $
      grandTotal r >= 0

couponName :: Coupon -> String
couponName NoCoupon       = "NoCoupon"
couponName (PercentOff _) = "PercentOff"
couponName (FlatOff _)    = "FlatOff"
couponName FreeShipping   = "FreeShipping"

-- Ch2: 全域性
totalityProps :: [P]
totalityProps =
  [ P "checkout never crashes"
      (\(ValidCart c) -> let r = checkout c
                         in total (subtotal r, discount r, shipping r, grandTotal r))
  ]

-- Ch9: 回帰テスト
regressionProps :: [P]
regressionProps =
  [ P "#1 FlatOff larger than subtotal"
      (once (let c = Cart [Item "a" 100 1] (FlatOff 99999) False
             in counterexample (show (checkout c))
                  (grandTotal (checkout c) === 0 + 500)))
  , P "#2 empty cart pays no shipping"
      (once (shipping (checkout (Cart [] NoCoupon False)) === 0))
  , P "#3 exactly 5000 ships free"
      (once (shipping (checkout (Cart [Item "a" 5000 1] NoCoupon False)) === 0))
  , P "#4 4999 pays shipping"
      (once (shipping (checkout (Cart [Item "a" 4999 1] NoCoupon False)) === 500))
  ]

------------------------------------------------------------
-- 実行
------------------------------------------------------------
runSection :: String -> [P] -> IO Bool
runSection title ps = do
  putStrLn ("-- " ++ title ++ " " ++ replicate (max 0 (48 - length title)) '-')
  rs <- mapM one ps
  pure (and rs)
  where
    one (P name p) = do
      putStr ("  " ++ pad 44 name)
      r <- quickCheckWithResult stdArgs { chatty = False, maxSuccess = 300 } p
      if isSuccess r
        then putStrLn "ok" >> pure True
        else do
          putStrLn "FAIL"
          putStrLn (unlines (map ("      " ++) (lines (output r))))
          pure False
    pad n s = s ++ replicate (n - length s) ' '

main :: IO ()
main = do
  putStrLn "--- sample carts ---"
  cs <- sample' (arbitrary :: Gen ValidCart)
  mapM_ (\(ValidCart c) ->
           putStrLn ("  " ++ show (length (cartItems c)) ++ " items, "
                       ++ couponName (cartCoupon c)
                       ++ (if isMember c then ", member" else "")
                       ++ " -> " ++ show (checkout c)))
        (take 5 cs)
  putStrLn ""

  putStrLn "--- measured distribution (Ch7: measure before you set thresholds) ---"
  quickCheckWith stdArgs { maxSuccess = 2000 } prop_measure
  putStrLn ""

  oks <- sequence
    [ runSection "Ch4/Ch5: generator and shrink" genProps
    , runSection "Ch2: invariants"               invariantProps
    , runSection "Ch2: metamorphic relations"    metamorphicProps
    , runSection "Ch2: specification"            specProps
    , runSection "Ch7: coverage"                 coverageProps
    , runSection "Ch2: totality"                 totalityProps
    , runSection "Ch9: regression"               regressionProps
    ]

  putStrLn (replicate 52 '=')
  putStrLn (if and oks then "  ALL GREEN" else "  SOME FAILURES")
  putStrLn (replicate 52 '=')
  putStrLn ""
  putStrLn checklist

checklist :: String
checklist = unlines
  [ "=== Final checklist ==="
  , ""
  , "Generators"
  , "  [ ] invariants hold by construction, not by filtering"
  , "  [ ] recursive types use sized"
  , "  [ ] boundary values are reachable (0, empty, max)"
  , "  [ ] the generator itself has properties"
  , ""
  , "Shrinking"
  , "  [ ] every custom Arbitrary defines shrink"
  , "  [ ] shrink preserves invariants"
  , "  [ ] shrink never returns the original value"
  , "  [ ] counterexamples are small enough to read"
  , ""
  , "Preconditions"
  , "  [ ] discarded count is close to zero"
  , "  [ ] standard modifiers used where they fit"
  , "  [ ] complex constraints are built, not filtered"
  , ""
  , "Coverage"
  , "  [ ] classify / tabulate checked at least once"
  , "  [ ] important branches guarded with cover"
  , "  [ ] checkCoverage on at least one generator guard"
  , ""
  , "Properties"
  , "  [ ] not a reimplementation of the code under test"
  , "  [ ] not a tautology (would fail if the code were undefined)"
  , "  [ ] a deliberately broken implementation makes them fail"
  , "  [ ] counterexample adds context on failure"
  , ""
  , "Project"
  , "  [ ] generators live in their own modules"
  , "  [ ] regression tests exist for every fixed bug"
  , "  [ ] dev / ci / nightly profiles are defined"
  , "  [ ] the seed is printed so failures can be reproduced"
  , "  [ ] CI runs the tests with --test-show-details=direct"
  ]

-- おつかれさまでした。
--
-- 次にやること:
--   1. ../project を cabal test で動かす
--   2. 自分のプロジェクトで、純粋関数を1つ選ぶ
--   3. Ch2 のパターン集を順に当てはめて、性質を3つ書く
--   4. わざと実装を壊して、落ちることを確かめる (Example 99)
--   5. 生成器を書き、classify で分布を見る (Ch7)
--   6. 見つけたバグを直し、回帰テストを足す (Example 95)
--   7. CI に載せる (Example 96)
--
-- さらに先へ:
--   * quickcheck-state-machine / quickcheck-dynamic
--       Example 88 の骨組みを汎用化したライブラリ。並行テストもできます。
--   * hedgehog
--       生成器と縮小が一体になった設計。shrink を書く必要がありません。
--   * tasty-quickcheck / hspec
--       テストフレームワークとの統合。--quickcheck-replay が便利です。
--   * validity / genvalidity
--       「型の妥当性」を中心に据えたアプローチ。
--   * MuCheck
--       変異テストの自動化 (Example 99 の自動版)。
