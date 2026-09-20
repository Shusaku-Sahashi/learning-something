-- Example 81: IO を含むプロパティ (ioProperty)
--
-- ここから Ch8「実際のコードに適用する」です。
-- まずは IO です。ファイル、DB、ネットワーク、可変参照を扱うコードのテスト。
--
-- 実行: runghc Example81.hs
module Main (main) where

import Data.IORef
import Test.QuickCheck

-- ioProperty :: Testable prop => IO prop -> Property
--   IO アクションを実行して、その結果をプロパティとして扱います。

------------------------------------------------------------
-- 例1: IORef を使ったカウンタ
------------------------------------------------------------
data Counter = Counter (IORef Int)

newCounter :: IO Counter
newCounter = Counter <$> newIORef 0

increment :: Counter -> IO ()
increment (Counter r) = modifyIORef' r (+ 1)

addN :: Counter -> Int -> IO ()
addN (Counter r) n = modifyIORef' r (+ n)

readCounter :: Counter -> IO Int
readCounter (Counter r) = readIORef r

reset :: Counter -> IO ()
reset (Counter r) = writeIORef r 0

-- n 回 increment したら、値は n になる
prop_incrementN :: NonNegative Int -> Property
prop_incrementN (NonNegative n) = ioProperty $ do
  c <- newCounter
  mapM_ (const (increment c)) [1 .. n]
  v <- readCounter c
  pure (v == n)

-- addN は increment の繰り返しと同じ
prop_addNEqualsIncrements :: NonNegative Int -> Property
prop_addNEqualsIncrements (NonNegative n) = ioProperty $ do
  c1 <- newCounter
  addN c1 n
  v1 <- readCounter c1

  c2 <- newCounter
  mapM_ (const (increment c2)) [1 .. n]
  v2 <- readCounter c2

  pure (v1 == v2)

-- reset のあとは必ず 0
prop_resetIsZero :: [Int] -> Property
prop_resetIsZero ns = ioProperty $ do
  c <- newCounter
  mapM_ (addN c) ns
  reset c
  v <- readCounter c
  pure (v == 0)

-- 操作列を適用したら、値は合計になる
prop_sumOfOps :: [Int] -> Property
prop_sumOfOps ns = ioProperty $ do
  c <- newCounter
  mapM_ (addN c) ns
  v <- readCounter c
  pure (v == sum ns)

------------------------------------------------------------
-- ioProperty は Property も返せる (=== が使えて便利)
------------------------------------------------------------
prop_sumWithDiff :: [Int] -> Property
prop_sumWithDiff ns = ioProperty $ do
  c <- newCounter
  mapM_ (addN c) ns
  v <- readCounter c
  pure (v === sum ns)

------------------------------------------------------------
-- 注意点: 状態を共有しないこと
------------------------------------------------------------
-- 下のように「外で作ったカウンタ」を使い回すと、
-- 前のテストの結果が次のテストに漏れます。
-- ioProperty の中で毎回作り直すのが鉄則です。
prop_sharedStateIsWrong :: Counter -> Int -> Property
prop_sharedStateIsWrong c n = ioProperty $ do
  reset c                       -- 明示的にリセットすれば使い回せるが、
  addN c n                      -- 忘れると壊れる。原則として共有しない。
  v <- readCounter c
  pure (v == n)

main :: IO ()
main = do
  putStr "increment n times    : " >> quickCheck prop_incrementN
  putStr "addN = increments    : " >> quickCheck prop_addNEqualsIncrements
  putStr "reset gives 0        : " >> quickCheck prop_resetIsZero
  putStr "sum of operations    : " >> quickCheck prop_sumOfOps
  putStr "with (===)           : " >> quickCheck prop_sumWithDiff

  putStrLn ""
  putStrLn "--- shared state (works only because we reset explicitly) ---"
  shared <- newCounter
  quickCheck (prop_sharedStateIsWrong shared)

-- ioProperty の注意点:
--
--   1. 毎回まっさらな状態を作る。
--      テストの実行順に依存するテストは、必ずいつか壊れます。
--
--   2. 副作用が外に漏れないようにする。
--      ファイルを作るなら一時ディレクトリに。DB なら都度ロールバック。
--
--   3. ioProperty の中で失敗しても、shrink は動きます。
--      ただし縮小のたびに IO が再実行されるので、遅い IO だと縮小も遅くなります。
--
--   4. 例外が出たら、それも失敗として報告されます (Example 83)。
--
-- より細かく制御したい場合は monadicIO を使います (Example 82)。
