-- Example 50: shrink を組み立てる部品
--
-- QuickCheck は shrink を書くためのヘルパーをいくつか用意しています。
--
-- 実行: runghc Example50.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- shrinkList :: (a -> [a]) -> [a] -> [[a]]
--   リストの shrink を、要素の shrink から作る。
------------------------------------------------------------
-- 「要素は縮めず、削るだけ」にしたい場合
shrinkOnlyDrop :: [Int] -> [[Int]]
shrinkOnlyDrop = shrinkList (const [])

-- 「要素も縮める」(標準の shrink と同じ)
shrinkDeep :: [Int] -> [[Int]]
shrinkDeep = shrinkList shrink

------------------------------------------------------------
-- shrinkNothing :: a -> [a]
--   「縮小しない」。常に [] を返す。
------------------------------------------------------------
newtype Opaque = Opaque Int
  deriving (Show, Eq)

instance Arbitrary Opaque where
  arbitrary = Opaque <$> arbitrary
  shrink    = shrinkNothing       -- 明示的に「縮小しない」と書く

------------------------------------------------------------
-- shrinkIntegral / shrinkRealFrac
--   数値型の shrink を借りる。
------------------------------------------------------------
newtype Meters = Meters Int
  deriving (Show, Eq)

instance Arbitrary Meters where
  arbitrary = Meters <$> choose (0, 10000)
  shrink (Meters n) = [ Meters n' | n' <- shrinkIntegral n, n' >= 0 ]

------------------------------------------------------------
-- shrinkMap :: (a -> b) -> (b -> a) -> b -> [b]
--   「別の型に変換して shrink し、戻す」。
--   newtype や、内部表現が別にある型で便利です。
------------------------------------------------------------
newtype Csv = Csv String
  deriving (Show, Eq)

toFields :: Csv -> [String]
toFields (Csv s) = splitOn ',' s

fromFields :: [String] -> Csv
fromFields = Csv . intercalate' ","

splitOn :: Char -> String -> [String]
splitOn c s = case break (== c) s of
  (a, [])      -> [a]
  (a, _ : rest) -> a : splitOn c rest

intercalate' :: String -> [String] -> String
intercalate' _   []       = ""
intercalate' _   [x]      = x
intercalate' sep (x : xs) = x ++ sep ++ intercalate' sep xs

instance Arbitrary Csv where
  arbitrary = fromFields <$> listOf1 (listOf (elements ['a' .. 'e']))
  -- 文字列としてではなく「フィールドのリスト」として縮小する。
  -- そのほうが意味のある縮小になります。
  shrink = shrinkMap fromFields toFields

------------------------------------------------------------
-- 縮小を確かめるプロパティ
------------------------------------------------------------
prop_csvFieldCount :: Csv -> Bool
prop_csvFieldCount c = length (toFields c) < 4

prop_metersSmall :: Meters -> Bool
prop_metersSmall (Meters n) = n < 500

prop_opaqueSmall :: Opaque -> Bool
prop_opaqueSmall (Opaque n) = n < 50

main :: IO ()
main = do
  putStrLn "--- shrinkList (const []) : only drop elements ---"
  print (shrinkOnlyDrop [1, 2, 3])
  putStrLn ""

  putStrLn "--- shrinkList shrink : drop and shrink elements ---"
  print (shrinkDeep [1, 2, 3])
  putStrLn ""

  putStrLn "--- shrinkNothing ---"
  print (shrink (Opaque 42))
  putStrLn ""

  putStrLn "--- shrinkIntegral, clamped to >= 0 ---"
  print (shrink (Meters 800))
  putStrLn ""

  putStrLn "--- shrinkMap on a CSV-like newtype ---"
  print (Csv "ab,cd,ef")
  mapM_ print (take 6 (shrink (Csv "ab,cd,ef")))
  putStrLn ""

  putStrLn "--- counterexamples ---"
  putStrLn "Csv (field count):"
  quickCheck prop_csvFieldCount
  putStrLn "Meters:"
  quickCheck prop_metersSmall
  putStrLn "Opaque (shrinkNothing, so the counterexample stays big):"
  quickCheck prop_opaqueSmall

-- 部品の一覧:
--   shrinkNothing   :: a -> [a]                      縮小しない
--   shrinkIntegral  :: Integral a => a -> [a]        整数の縮小
--   shrinkRealFrac  :: RealFrac a => a -> [a]        小数の縮小
--   shrinkList      :: (a -> [a]) -> [a] -> [[a]]    リストの縮小
--   shrinkMap       :: (a -> b) -> (b -> a) -> b -> [b]
--                                                    変換してから縮小
--   shrinkMapBy     :: (a -> b) -> (b -> a) -> (a -> [a]) -> b -> [b]
--                                                    縮小関数も指定する版
--   genericShrink   :: (Generic a, ...) => a -> [a]  自動導出 (Example 51)
--
-- shrinkMap は「内部表現が違う型」でとても役に立ちます。
-- 上の Csv の例では、文字を1つずつ削るのではなく
-- 「フィールドを1つ削る」縮小になるので、反例がずっと読みやすくなります。
