-- Example 45: Arbitrary インスタンスにするか、forAll にするか
--
-- 実務で必ず迷うところなので、判断基準をはっきりさせておきます。
--
-- 実行: runghc Example45.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 判断基準
------------------------------------------------------------
-- Arbitrary インスタンスにすべき場合:
--   * その型の「標準的な値」が1つに決まる
--   * 多くのテストで同じ生成方法を使う
--   * 型が自分のプロジェクトのもの (orphan instance にならない)
--
-- forAll (またはその場の Gen) にすべき場合:
--   * テストごとに違う生成方法が要る
--   * 「この条件を満たす値」という、その場限りの要求
--   * 他人のライブラリの型 (orphan instance を避けたい)
--   * 標準の Arbitrary はあるが、このテストでは別の分布が欲しい

------------------------------------------------------------
-- 例: ポート番号
------------------------------------------------------------
newtype Port = Port Int
  deriving (Show, Eq, Ord)

-- 標準的な生成方法がはっきりしているので Arbitrary にする
instance Arbitrary Port where
  arbitrary = Port <$> choose (1, 65535)

isPrivileged :: Port -> Bool
isPrivileged (Port p) = p < 1024

prop_portInRange :: Port -> Bool
prop_portInRange (Port p) = p >= 1 && p <= 65535

-- しかし「特権ポートだけ」を試したいテストもあります。
-- そういうときは、その場の生成器を forAll で渡します。
genPrivileged :: Gen Port
genPrivileged = Port <$> choose (1, 1023)

genUnprivileged :: Gen Port
genUnprivileged = Port <$> choose (1024, 65535)

prop_privilegedDetected :: Property
prop_privilegedDetected = forAll genPrivileged isPrivileged

prop_unprivilegedDetected :: Property
prop_unprivilegedDetected = forAll genUnprivileged (not . isPrivileged)

------------------------------------------------------------
-- 例: 他人の型に対する生成 (orphan instance 問題)
------------------------------------------------------------
-- Data.Ratio の Ratio Int に Arbitrary を書きたい、としましょう。
-- 自分のモジュールで書くと orphan instance になり、
-- 別のライブラリが同じインスタンスを定義すると衝突します。
--
-- 解決策1: newtype でラップする
newtype MyRatio = MyRatio (Int, Int)     -- (分子, 分母) の簡易表現
  deriving (Show, Eq)

instance Arbitrary MyRatio where
  arbitrary = do
    n <- arbitrary
    d <- arbitrary `suchThat` (/= 0)
    pure (MyRatio (n, d))

-- 解決策2: forAll でその場の生成器を使う (インスタンスを一切書かない)
genRatioPair :: Gen (Int, Int)
genRatioPair = do
  n <- arbitrary
  d <- arbitrary `suchThat` (/= 0)
  pure (n, d)

ratioValue :: (Int, Int) -> Double
ratioValue (n, d) = fromIntegral n / fromIntegral d

prop_ratioFinite :: Property
prop_ratioFinite = forAll genRatioPair (not . isNaN . ratioValue)

------------------------------------------------------------
-- 両方を混ぜる: Arbitrary を基本にしつつ、必要なときだけ上書き
------------------------------------------------------------
data Server = Server { srvHost :: String, srvPort :: Port }
  deriving (Show, Eq)

instance Arbitrary Server where
  arbitrary = Server <$> elements ["localhost", "example.com"] <*> arbitrary

-- 普段はこれでよい
prop_serverPortValid :: Server -> Bool
prop_serverPortValid s = prop_portInRange (srvPort s)

-- 「特権ポートのサーバ」だけ試したいテストでは forAll で上書き
genPrivilegedServer :: Gen Server
genPrivilegedServer = Server <$> elements ["localhost"] <*> genPrivileged

needsRoot :: Server -> Bool
needsRoot = isPrivileged . srvPort

prop_privilegedServerNeedsRoot :: Property
prop_privilegedServerNeedsRoot = forAll genPrivilegedServer needsRoot

main :: IO ()
main = do
  putStrLn "--- Arbitrary instance (default distribution) ---"
  ps <- sample' (arbitrary :: Gen Port)
  print ps

  putStrLn "--- forAll with a narrower generator ---"
  qs <- sample' genPrivileged
  print qs

  putStrLn ""
  putStrLn "--- properties ---"
  putStr "port in range          : " >> quickCheck prop_portInRange
  putStr "privileged detected    : " >> quickCheck prop_privilegedDetected
  putStr "unprivileged detected  : " >> quickCheck prop_unprivilegedDetected
  putStr "ratio is finite        : " >> quickCheck prop_ratioFinite
  putStr "server port valid      : " >> quickCheck prop_serverPortValid
  putStr "privileged needs root  : " >> quickCheck prop_privilegedServerNeedsRoot

  putStrLn ""
  putStrLn "--- how often does the default generator hit a privileged port? ---"
  draws <- sequence (replicate 1000 (generate (arbitrary :: Gen Port)))
  putStrLn ("  privileged out of 1000: " ++ show (length (filter isPrivileged draws)))
  putStrLn "  ^ about 1.5%. Far too rare to rely on for testing that branch."

-- 最後の実験が、この Example の本題です。
--
--   Arbitrary の「標準の分布」に任せていると、
--   特定の分岐にほとんど到達しません。
--
-- だから:
--   1. 型には「無難な」Arbitrary を書いておく
--   2. 特定の条件を狙うテストでは forAll で専用生成器を使う
--   3. 到達率が気になったら classify / cover で測る (Ch7)
--
-- この3点セットが実務のパターンです。
