-- Example 46: Ch4 総合演習「在庫管理の型を丸ごとテストする」
--
-- Ch3-4 で学んだ生成の技を、1つの題材で全部使います。
--
-- 実行: runghc Example46.hs
module Main (main) where

import Data.List (sort)
import qualified Data.Map.Strict as M
import Test.QuickCheck

------------------------------------------------------------
-- ドメイン
------------------------------------------------------------
newtype Sku = Sku String
  deriving (Show, Eq, Ord)

data Item = Item
  { itemSku      :: Sku
  , itemName     :: String
  , itemPrice    :: Int          -- 単位: 円。負にはならない
  , itemQty      :: Int          -- 在庫数。負にはならない
  }
  deriving (Show, Eq)

newtype Inventory = Inventory (M.Map Sku Item)
  deriving (Show, Eq)

------------------------------------------------------------
-- 操作
------------------------------------------------------------
emptyInv :: Inventory
emptyInv = Inventory M.empty

addItem :: Item -> Inventory -> Inventory
addItem it (Inventory m) = Inventory (M.insertWith merge (itemSku it) it m)
  where merge new old = old { itemQty = itemQty old + itemQty new }

removeQty :: Sku -> Int -> Inventory -> Inventory
removeQty sku n (Inventory m) = Inventory (M.adjust dec sku m)
  where dec it = it { itemQty = max 0 (itemQty it - n) }

totalValue :: Inventory -> Int
totalValue (Inventory m) = sum [ itemPrice it * itemQty it | it <- M.elems m ]

skus :: Inventory -> [Sku]
skus (Inventory m) = M.keys m

lookupItem :: Sku -> Inventory -> Maybe Item
lookupItem sku (Inventory m) = M.lookup sku m

------------------------------------------------------------
-- 生成器: 部品から組み立てる (Example 39 の方式)
------------------------------------------------------------
genSkuString :: Gen String
genSkuString = do
  prefix <- elements ["AA", "BB", "CC", "ZZ"]
  n      <- choose (100 :: Int, 999)
  pure (prefix ++ "-" ++ show n)

instance Arbitrary Sku where
  arbitrary = Sku <$> genSkuString

genItemName :: Gen String
genItemName = do
  n <- choose (1, 20)
  vectorOf n (elements (['a' .. 'z'] ++ " "))

instance Arbitrary Item where
  arbitrary = Item
    <$> arbitrary
    <*> genItemName
    <*> frequency [ (8, choose (1, 100000)), (1, pure 0), (1, choose (100001, 10000000)) ]
    <*> frequency [ (8, choose (1, 100)),    (1, pure 0), (1, choose (101, 100000)) ]

instance Arbitrary Inventory where
  -- スマートコンストラクタ (addItem) を通すので、不変条件が自動的に保たれます
  arbitrary = foldr addItem emptyInv <$> listOf arbitrary

-- 狙い撃ち生成器: 「空でない在庫と、そこに実在する SKU」
genInvAndSku :: Gen (Inventory, Sku)
genInvAndSku = do
  items <- listOf1 arbitrary
  let inv = foldr addItem emptyInv items
  sku <- elements (skus inv)
  pure (inv, sku)

------------------------------------------------------------
-- プロパティ
------------------------------------------------------------
-- 不変条件: 数量も価格も負にならない
prop_noNegatives :: Inventory -> Bool
prop_noNegatives (Inventory m) =
  all (\it -> itemQty it >= 0 && itemPrice it >= 0) (M.elems m)

prop_removeKeepsNonNegative :: Sku -> NonNegative Int -> Inventory -> Bool
prop_removeKeepsNonNegative sku (NonNegative n) inv =
  prop_noNegatives (removeQty sku n inv)

-- 不変条件: キーと中身の SKU が一致している
prop_keysConsistent :: Inventory -> Bool
prop_keysConsistent (Inventory m) =
  all (\(k, it) -> k == itemSku it) (M.toList m)

-- 往復: 入れたら引ける
prop_addThenLookup :: Item -> Property
prop_addThenLookup it =
  case lookupItem (itemSku it) (addItem it emptyInv) of
    Just found -> itemSku found === itemSku it
    Nothing    -> counterexample "not found" False

-- 加算: 同じ SKU を2回足すと数量が合算される
prop_addSameSkuAccumulates :: Item -> Item -> Property
prop_addSameSkuAccumulates a b =
  let b' = b { itemSku = itemSku a }
      inv = addItem b' (addItem a emptyInv)
  in fmap itemQty (lookupItem (itemSku a) inv) === Just (itemQty a + itemQty b')

-- メタモルフィック: 品物を足すと総額は減らない
prop_addNeverDecreasesValue :: Item -> Inventory -> Property
prop_addNeverDecreasesValue it inv =
  counterexample (show (totalValue inv, totalValue (addItem it inv)))
    (totalValue (addItem it inv) >= totalValue inv)

-- メタモルフィック: 在庫を減らすと総額は増えない
prop_removeNeverIncreasesValue :: NonNegative Int -> Property
prop_removeNeverIncreasesValue (NonNegative n) =
  forAll genInvAndSku $ \(inv, sku) ->
    totalValue (removeQty sku n inv) <= totalValue inv

-- 局所性: 別の SKU を減らしても、この SKU は変わらない
prop_removeOtherSku :: Property
prop_removeOtherSku =
  forAll genInvAndSku $ \(inv, sku) ->
    forAll arbitrary $ \other ->
      other /= sku ==>
        lookupItem sku (removeQty other 1 inv) === lookupItem sku inv

-- 冪等性: 数量を大量に引く操作は、2回やっても同じ (0 で止まるため)
prop_removeHugeIdempotent :: Property
prop_removeHugeIdempotent =
  forAll genInvAndSku $ \(inv, sku) ->
    let once = removeQty sku 1000000 inv
    in removeQty sku 1000000 once === once

-- オラクル: 総額は「価格 x 数量」の単純な和に等しい
prop_totalValueOracle :: Inventory -> Property
prop_totalValueOracle inv@(Inventory m) =
  totalValue inv === sum (map (\it -> itemPrice it * itemQty it) (M.elems m))

-- 全域性
prop_totalOps :: Item -> Sku -> Inventory -> Property
prop_totalOps it sku inv =
  total ( totalValue (addItem it inv)
        , totalValue (removeQty sku 5 inv)
        , sort (map (\(Sku s) -> s) (skus inv)) )

main :: IO ()
main = do
  putStrLn "--- sample items ---"
  its <- sample' (arbitrary :: Gen Item)
  mapM_ print (take 4 its)

  putStrLn ""
  putStrLn "--- sample inventory sizes ---"
  invs <- sample' (arbitrary :: Gen Inventory)
  print (map (length . skus) invs)

  putStrLn ""
  putStrLn "--- invariants ---"
  putStr "no negatives          : " >> quickCheck prop_noNegatives
  putStr "remove keeps >= 0     : " >> quickCheck prop_removeKeepsNonNegative
  putStr "keys consistent       : " >> quickCheck prop_keysConsistent

  putStrLn "--- round trip ---"
  putStr "add then lookup       : " >> quickCheck prop_addThenLookup
  putStr "same sku accumulates  : " >> quickCheck prop_addSameSkuAccumulates

  putStrLn "--- metamorphic ---"
  putStr "add does not decrease : " >> quickCheck prop_addNeverDecreasesValue
  putStr "remove does not raise : " >> quickCheck prop_removeNeverIncreasesValue
  putStr "remove other sku      : " >> quickCheck prop_removeOtherSku

  putStrLn "--- idempotence / oracle / totality ---"
  putStr "remove huge idempotent: " >> quickCheck prop_removeHugeIdempotent
  putStr "total value oracle    : " >> quickCheck prop_totalValueOracle
  putStr "no crashes            : " >> quickCheck prop_totalOps

-- Ch4 のまとめ:
--   1. 自作型の Arbitrary は、スマートコンストラクタを通して書く
--   2. 再帰的な型は必ず sized で書く
--   3. 生成器は部品に分けて使い回す
--   4. 「狙い撃ち生成器」を別に用意して forAll で使う
--   5. 生成器自体にもプロパティを書く
--   6. newtype ラッパーで生成戦略を切り替える
--   7. 関数が必要なら Fun を使う
--
-- 次の Ch5 では、まだ書いていない shrink を扱います。
-- ここまでの Arbitrary はすべて shrink を省略しているので、
-- 反例が大きくて読みにくいはずです。それを直します。
