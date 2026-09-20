-- Example 79: 分布を測るユーティリティを作る
--
-- 毎回 classify を書き足すのは面倒です。
-- 測定用のヘルパーを1つ作っておくと、日々の開発が楽になります。
--
-- 実行: runghc Example79.hs
module Main (main) where

import Data.List (sortBy, group, sort)
import Data.Ord (comparing, Down (..))
import Test.QuickCheck

------------------------------------------------------------
-- 生成器の分布を、その場で表示するヘルパー
------------------------------------------------------------
-- QuickCheck の classify/tabulate はプロパティに埋め込む必要がありますが、
-- 「生成器だけ調べたい」ときは、こういう関数のほうが手軽です。
distribution :: Ord b => Int -> Gen a -> (a -> b) -> IO [(b, Int)]
distribution n gen key = do
  xs <- sequence (replicate n (generate gen))
  let ks = map key xs
  pure (sortBy (comparing (Down . snd)) (counts ks))
  where
    counts = map (\g -> (head g, length g)) . group . sort

report :: (Ord b, Show b) => String -> Int -> Gen a -> (a -> b) -> IO ()
report title n gen key = do
  putStrLn ("  " ++ title)
  ds <- distribution n gen key
  mapM_ (\(k, c) ->
           putStrLn ("    " ++ pad 18 (show k) ++ pct c n ++ bar c n))
        (take 10 ds)
  where
    pad w s = s ++ replicate (w - length s) ' '
    pct c total =
      let p = (100 * c) `div` total
      in pad 6 (show p ++ "%")
    bar c total = replicate ((40 * c) `div` total) '#'

------------------------------------------------------------
-- 測ってみる
------------------------------------------------------------
data Shape = Circle Int | Square Int | Tri Int Int Int
  deriving (Show, Eq)

shapeName :: Shape -> String
shapeName (Circle _)  = "Circle"
shapeName (Square _)  = "Square"
shapeName (Tri _ _ _) = "Tri"

genShapeV1 :: Gen Shape
genShapeV1 = oneof
  [ Circle <$> choose (1, 100)
  , Square <$> choose (1, 100)
  , Tri <$> choose (1, 100) <*> choose (1, 100) <*> choose (1, 100)
  ]

genShapeV2 :: Gen Shape
genShapeV2 = frequency
  [ (5, Circle <$> choose (1, 100))
  , (3, Square <$> choose (1, 100))
  , (2, Tri <$> choose (1, 100) <*> choose (1, 100) <*> choose (1, 100))
  ]

------------------------------------------------------------
-- 「生成器ガード」プロパティ: CI に置いて分布を守る
------------------------------------------------------------
-- 対象のロジックは一切テストしません。
-- 「生成器がまだ健全か」だけを見ます。
prop_shapeGeneratorHealthy :: Property
prop_shapeGeneratorHealthy =
  checkCoverage $
  forAll genShapeV2 $ \s ->
    tabulate "shape" [shapeName s] $
    coverTable "shape" [ ("Circle", 30), ("Square", 20), ("Tri", 10) ] $
      True

-- リストの長さについても同じことができます。
prop_listLengthHealthy :: Property
prop_listLengthHealthy =
  checkCoverage $
  forAll (arbitrary :: Gen [Int]) $ \xs ->
    cover 3  (null xs)          "empty"      $
    cover 2  (length xs == 1)   "singleton"  $
    cover 30 (length xs >= 5)   "5 or more"  $
    cover 10 (length xs >= 20)  "20 or more" $
      True

main :: IO ()
main = do
  putStrLn "--- distribution of genShapeV1 (oneof) ---"
  report "by constructor" 2000 genShapeV1 shapeName
  putStrLn ""

  putStrLn "--- distribution of genShapeV2 (frequency 5:3:2) ---"
  report "by constructor" 2000 genShapeV2 shapeName
  putStrLn ""

  putStrLn "--- distribution of list lengths ---"
  report "length bucket" 2000 (arbitrary :: Gen [Int]) lenBucket
  putStrLn ""

  putStrLn "--- distribution of Int sign ---"
  report "sign" 2000 (arbitrary :: Gen Int) signName
  putStrLn ""

  putStrLn "--- generator guard properties ---"
  putStr "shape generator : " >> quickCheck prop_shapeGeneratorHealthy
  putStr "list lengths    : " >> quickCheck prop_listLengthHealthy
  where
    lenBucket xs
      | null xs         = "0"
      | length xs == 1  = "1"
      | length xs <= 5  = "2-5"
      | length xs <= 20 = "6-20"
      | otherwise       = "21+"
    signName n
      | n < 0     = "neg" :: String
      | n == 0    = "zero"
      | otherwise = "pos"

-- 運用の提案:
--
--   1. 生成器ごとに「ガードプロパティ」を1本書く
--        prop_xxxGeneratorHealthy :: Property
--      対象ロジックはテストしない。分布だけを固定する。
--
--   2. CI で回す。生成器を誰かが変えたら、ここが落ちる。
--
--   3. しきい値は「実測値の半分〜2/3」にします。
--      上の "singleton" は実測 4% 前後なので、5% にすると
--      実行のゆらぎで落ちます (最初 5% と書いて落ちました)。2% が妥当です。
--
--   4. 落ちたら「意図した変更か」を判断する。
--      意図したものなら cover の数値を更新する。
--      意図しないものなら生成器を直す。
--
--   5. 開発中は report のようなヘルパーで、目で見て確認する。
--
-- この5点を回していれば、「何も試していないテスト」は生まれません。
--
-- なお report は QuickCheck の機能ではなく、この Example で書いた
-- ただのヘルパー関数です。自分のプロジェクトにコピーして使ってください。
