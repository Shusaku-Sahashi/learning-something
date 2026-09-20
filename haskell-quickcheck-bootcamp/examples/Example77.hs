-- Example 77: 分布が悪くてバグを見逃す (完全な実例)
--
-- 「テストは全部通っているのに本番で落ちた」という事故を、
-- 最初から最後まで再現します。Ch7 で一番大事な Example です。
--
-- 実行: runghc Example77.hs
module Main (main) where

import Data.List (sortBy)
import Data.Ord (comparing)
import Test.QuickCheck

------------------------------------------------------------
-- 題材: 商品を「在庫あり優先、そのあと価格の安い順」で並べる
------------------------------------------------------------
data Product = Product
  { name    :: String
  , price   :: Int
  , inStock :: Bool
  }
  deriving (Show, Eq)

-- バグあり実装:
--   在庫の有無でソートしたあと、価格でソートし直している。
--   2回目のソートで、在庫の並びが崩れてしまう…
--   と思いきや、Data.List.sortBy は安定ソートなので崩れません。
--   本当のバグは「比較の順序が逆」なことです。
rankBuggy :: [Product] -> [Product]
rankBuggy = sortBy (comparing price) . sortBy (comparing (not . inStock))
--                                             ^^^ これを先にやっても
--                                                 あとの価格ソートで上書きされる

-- 正しい実装: 1回の比較で両方の基準を見る
rankGood :: [Product] -> [Product]
rankGood = sortBy (comparing (\p -> (not (inStock p), price p)))

------------------------------------------------------------
-- 仕様: 在庫ありの商品は、在庫なしの商品より前に来る
------------------------------------------------------------
inStockFirst :: [Product] -> Bool
inStockFirst ps =
  let flags = map inStock ps
  in flags == reverse (sortOnBool flags)
  where
    sortOnBool bs = filter not bs ++ filter id bs

------------------------------------------------------------
-- 悪い生成器: ほとんどの商品が在庫ありになってしまう
------------------------------------------------------------
genProductBad :: Gen Product
genProductBad = Product
  <$> listOf1 (elements ['a' .. 'e'])
  <*> choose (100, 10000)
  <*> pure True                          -- ★ 常に在庫あり

newtype BadList = BadList [Product]
  deriving (Show)

instance Arbitrary BadList where
  arbitrary = BadList <$> listOf genProductBad
  -- 反例を読めるように、要素を削る縮小を入れておきます (Ch5)
  shrink (BadList ps) = [ BadList ps' | ps' <- shrinkList (const []) ps ]

------------------------------------------------------------
-- ましな生成器: 在庫の有無は出るが、偏っている
------------------------------------------------------------
genProductSkewed :: Gen Product
genProductSkewed = Product
  <$> listOf1 (elements ['a' .. 'e'])
  <*> choose (100, 10000)
  <*> frequency [ (19, pure True), (1, pure False) ]   -- 5% しか在庫なしが出ない

newtype SkewedList = SkewedList [Product]
  deriving (Show)

instance Arbitrary SkewedList where
  arbitrary = SkewedList <$> listOf genProductSkewed
  shrink (SkewedList ps) = [ SkewedList ps' | ps' <- shrinkList (const []) ps ]

------------------------------------------------------------
-- 良い生成器: 在庫の有無が半々、リストも十分な長さ
------------------------------------------------------------
genProductGood :: Gen Product
genProductGood = Product
  <$> listOf1 (elements ['a' .. 'e'])
  <*> choose (100, 10000)
  <*> arbitrary

newtype GoodList = GoodList [Product]
  deriving (Show)

instance Arbitrary GoodList where
  arbitrary = do
    n <- choose (2, 10)
    GoodList <$> vectorOf n genProductGood
  shrink (GoodList ps) =
    [ GoodList ps' | ps' <- shrinkList (const []) ps, length ps' >= 2 ]

------------------------------------------------------------
-- 同じプロパティを、3つの生成器で試す
------------------------------------------------------------
prop_bad :: BadList -> Property
prop_bad (BadList ps) =
  classify (any (not . inStock) ps) "has an out-of-stock item" $
  classify (length ps >= 2)         "at least 2 items"         $
    inStockFirst (rankBuggy ps)

prop_skewed :: SkewedList -> Property
prop_skewed (SkewedList ps) =
  classify (any (not . inStock) ps) "has an out-of-stock item" $
  classify (mixed ps)               "has BOTH in and out of stock" $
    inStockFirst (rankBuggy ps)

prop_good :: GoodList -> Property
prop_good (GoodList ps) =
  classify (mixed ps) "has BOTH in and out of stock" $
    inStockFirst (rankBuggy ps)

prop_goodImpl :: GoodList -> Property
prop_goodImpl (GoodList ps) =
  classify (mixed ps) "has BOTH in and out of stock" $
    inStockFirst (rankGood ps)

-- カバレッジを強制すれば、悪い生成器は「テストとして失格」になる
prop_guarded :: Property
prop_guarded =
  checkCoverage $
  forAll (arbitrary :: Gen BadList) $ \(BadList ps) ->
    cover 30 (mixed ps) "has BOTH in and out of stock" $
      inStockFirst (rankBuggy ps)

mixed :: [Product] -> Bool
mixed ps = any inStock ps && any (not . inStock) ps

main :: IO ()
main = do
  putStrLn "--- generator 1: every product is in stock ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_bad
  putStrLn "  ^ PASSES. The bug is never exercised."
  putStrLn ""

  putStrLn "--- generator 2: only 5% out of stock ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_skewed
  putStrLn ""

  putStrLn "--- generator 3: balanced, lists of 2-10 ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_good
  putStrLn ""

  putStrLn "--- the same generator against the correct implementation ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_goodImpl
  putStrLn ""

  putStrLn "--- cover turns 'never exercised' into a test failure ---"
  quickCheck prop_guarded
  putStrLn ""

  putStrLn "--- the bug, shown concretely ---"
  let ps = [ Product "cheap-out" 100 False, Product "pricey-in" 900 True ]
  putStrLn ("  input      : " ++ show (map (\p -> (name p, price p, inStock p)) ps))
  putStrLn ("  rankBuggy  : " ++ show (map name (rankBuggy ps)))
  putStrLn ("  rankGood   : " ++ show (map name (rankGood ps)))

-- この Example の教訓:
--
--   1. 「テストが通った」は「バグがない」ではありません。
--      「試した範囲にバグがなかった」だけです。
--
--   2. 何を試したかは classify で見えます。
--      generator 1 の出力には "has an out-of-stock item" の行が
--      そもそも出てきません (QuickCheck は 0% のラベルを表示しません)。
--      「あるはずのラベルが無い」ことに気づけるかどうかが分かれ目です。
--      気づきにくいからこそ、次の cover が要ります。
--
--   3. cover + checkCoverage を書いておけば、
--      「試していない」ことが自動で失敗になります。
--      人間が毎回 classify の出力を読む必要はありません。
--
--   4. 生成器の初期値は pure True や pure "" になりがちです。
--      (「とりあえず動かす」ために書いたものが残る)
--      cover はこの種の事故を確実に止めてくれます。
--
-- 運用の提案:
--   重要なプロパティには、必ず1つは cover を書く。
--   書けないなら、そのプロパティが何を検査しているのか、
--   自分でも分かっていない可能性があります。
