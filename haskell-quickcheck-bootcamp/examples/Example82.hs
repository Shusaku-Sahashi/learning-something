-- Example 82: monadicIO で手続き的に書く
--
-- ioProperty は「IO を1つ実行して結果を返す」形でした。
-- monadicIO を使うと、途中で assert や pre を挟める手続き的な書き方ができます。
--
-- 実行: runghc Example82.hs
module Main (main) where

import Data.IORef
import Test.QuickCheck
import Test.QuickCheck.Monadic

------------------------------------------------------------
-- 道具
------------------------------------------------------------
-- monadicIO :: PropertyM IO a -> Property
-- run       :: IO a -> PropertyM IO a          IO アクションを実行する
-- assert    :: Bool -> PropertyM IO ()         条件を確かめる
-- pre       :: Bool -> PropertyM IO ()         前提条件 ((==>) に相当)
-- monitor   :: (Property -> Property) -> PropertyM IO ()
--                                              counterexample などを足す
-- pick      :: Show a => Gen a -> PropertyM IO a   途中で値を生成する

------------------------------------------------------------
-- 題材: 簡易キー・バリューストア (IORef 版)
------------------------------------------------------------
type Store = IORef [(String, Int)]

newStore :: IO Store
newStore = newIORef []

putKV :: Store -> String -> Int -> IO ()
putKV s k v = modifyIORef' s (\kvs -> (k, v) : filter ((/= k) . fst) kvs)

getKV :: Store -> String -> IO (Maybe Int)
getKV s k = lookup k <$> readIORef s

deleteKV :: Store -> String -> IO ()
deleteKV s k = modifyIORef' s (filter ((/= k) . fst))

sizeKV :: Store -> IO Int
sizeKV s = length <$> readIORef s

------------------------------------------------------------
-- 基本のプロパティ
------------------------------------------------------------
prop_putThenGet :: String -> Int -> Property
prop_putThenGet k v = monadicIO $ do
  s   <- run newStore
  run (putKV s k v)
  got <- run (getKV s k)
  assert (got == Just v)

prop_deleteThenGet :: String -> Int -> Property
prop_deleteThenGet k v = monadicIO $ do
  s   <- run newStore
  run (putKV s k v)
  run (deleteKV s k)
  got <- run (getKV s k)
  assert (got == Nothing)

------------------------------------------------------------
-- monitor で反例に情報を足す
------------------------------------------------------------
prop_sizeAfterPuts :: [(String, Int)] -> Property
prop_sizeAfterPuts kvs = monadicIO $ do
  s <- run newStore
  mapM_ (\(k, v) -> run (putKV s k v)) kvs
  n <- run (sizeKV s)
  let expected = length (distinctKeys (map fst kvs))
  monitor (counterexample ("size = " ++ show n ++ ", expected = " ++ show expected))
  assert (n == expected)
  where
    distinctKeys = foldr (\x acc -> if x `elem` acc then acc else x : acc) []

------------------------------------------------------------
-- pre で前提条件を書く
------------------------------------------------------------
prop_overwrite :: String -> Int -> Int -> Property
prop_overwrite k v1 v2 = monadicIO $ do
  pre (v1 /= v2)                 -- (==>) と同じ効果
  s <- run newStore
  run (putKV s k v1)
  run (putKV s k v2)
  got <- run (getKV s k)
  monitor (counterexample ("got = " ++ show got))
  assert (got == Just v2)

------------------------------------------------------------
-- pick で途中で値を生成する
------------------------------------------------------------
-- 「ストアに入れたキーのどれか」を選びたい場合、
-- 入れたあとでないと選べません。pick が役に立ちます。
prop_anyStoredKeyIsFound :: NonEmptyList (String, Int) -> Property
prop_anyStoredKeyIsFound (NonEmpty kvs) = monadicIO $ do
  s <- run newStore
  mapM_ (\(k, v) -> run (putKV s k v)) kvs
  k <- pick (elements (map fst kvs))
  got <- run (getKV s k)
  monitor (counterexample ("key = " ++ show k ++ ", got = " ++ show got))
  assert (got /= Nothing)

------------------------------------------------------------
-- 複数ステップの手続きを書く
------------------------------------------------------------
prop_sequence :: String -> String -> Int -> Property
prop_sequence k1 k2 v = monadicIO $ do
  pre (k1 /= k2)
  s <- run newStore
  run (putKV s k1 v)
  run (putKV s k2 (v + 1))
  run (deleteKV s k1)
  g1 <- run (getKV s k1)
  g2 <- run (getKV s k2)
  n  <- run (sizeKV s)
  monitor (counterexample ("g1=" ++ show g1 ++ " g2=" ++ show g2 ++ " n=" ++ show n))
  assert (g1 == Nothing && g2 == Just (v + 1) && n == 1)

main :: IO ()
main = do
  putStr "put then get       : " >> quickCheck prop_putThenGet
  putStr "delete then get    : " >> quickCheck prop_deleteThenGet
  putStr "size after puts    : " >> quickCheck prop_sizeAfterPuts
  putStr "overwrite          : " >> quickCheck prop_overwrite
  putStr "stored key is found: " >> quickCheck prop_anyStoredKeyIsFound
  putStr "a sequence of ops  : " >> quickCheck prop_sequence

-- ioProperty と monadicIO の使い分け:
--
--   ioProperty
--     * 短い。1つの IO を走らせて結果を見るだけ
--     * Property を返せるので === が使える
--
--   monadicIO
--     * 手順が長いとき
--     * 途中で assert したいとき
--     * 途中で値を生成したいとき (pick)
--     * monitor で情報を足したいとき
--
-- monadicIO の中で assert が失敗すると、そこで停止して失敗が報告されます。
-- 複数の assert を並べれば、「どの段階で壊れたか」が分かります。
--
-- なお pick で生成した値は shrink されません。
-- 縮小してほしい値は、プロパティの引数として受け取ってください。
