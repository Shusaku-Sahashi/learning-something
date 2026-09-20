-- Example 89: 並行処理のテスト
--
-- 競合状態 (race condition) をプロパティで検出します。
--
-- 注意: 並行バグは「たまたま起きる」ものなので、素朴に書くと再現しません。
--       この Example では yield を挟んで、確実に競合が起きるようにしています。
--       (実際のコードに yield を入れるわけではありません。
--        「起こりうる最悪のスケジュールを再現する」ためのテスト用の工夫です)
--
-- 実行: runghc Example89.hs
module Main (main) where

import Control.Concurrent (forkIO, yield)
import Control.Concurrent.MVar
import Data.IORef
import Test.QuickCheck

------------------------------------------------------------
-- 並行に実行して、全部終わるまで待つヘルパー
------------------------------------------------------------
runConcurrently :: [IO ()] -> IO ()
runConcurrently actions = do
  dones <- mapM (const newEmptyMVar) actions
  mapM_ (\(a, d) -> forkIO (a >> putMVar d ())) (zip actions dones)
  mapM_ takeMVar dones

------------------------------------------------------------
-- カウンタの3つの実装
------------------------------------------------------------
-- (1) 競合する実装: read してから write するまでの間に割り込まれる
incUnsafe :: IORef Int -> IO ()
incUnsafe r = do
  v <- readIORef r
  yield                     -- ここで他スレッドに切り替わる
  writeIORef r (v + 1)

-- (2) 正しい実装: atomicModifyIORef' で不可分に更新する
incAtomic :: IORef Int -> IO ()
incAtomic r = atomicModifyIORef' r (\v -> (v + 1, ()))

-- (3) 正しい実装: MVar で排他する
incMVar :: MVar Int -> IO ()
incMVar m = modifyMVar_ m (pure . (+ 1))

------------------------------------------------------------
-- プロパティ: n 個のスレッドが1回ずつ増やしたら、結果は n
------------------------------------------------------------
prop_unsafeCounter :: Property
prop_unsafeCounter =
  forAll (choose (2, 20)) $ \n -> ioProperty $ do
    r <- newIORef 0
    runConcurrently (replicate n (incUnsafe r))
    v <- readIORef r
    pure (counterexample ("threads = " ++ show n ++ ", counter = " ++ show v)
                         (v === n))

prop_atomicCounter :: Property
prop_atomicCounter =
  forAll (choose (2, 50)) $ \n -> ioProperty $ do
    r <- newIORef 0
    runConcurrently (replicate n (incAtomic r))
    v <- readIORef r
    pure (counterexample ("threads = " ++ show n ++ ", counter = " ++ show v)
                         (v === n))

prop_mvarCounter :: Property
prop_mvarCounter =
  forAll (choose (2, 50)) $ \n -> ioProperty $ do
    m <- newMVar 0
    runConcurrently (replicate n (incMVar m))
    v <- readMVar m
    pure (counterexample ("threads = " ++ show n ++ ", counter = " ++ show v)
                         (v === n))

------------------------------------------------------------
-- もう少し実務的な例: 銀行口座の送金
------------------------------------------------------------
data Bank = Bank (MVar Int) (MVar Int)

newBank :: Int -> Int -> IO Bank
newBank a b = Bank <$> newMVar a <*> newMVar b

-- 正しい送金: 合計は変わらない
transfer :: Bank -> Int -> IO ()
transfer (Bank from to) amount = do
  modifyMVar_ from (pure . subtract amount)
  modifyMVar_ to   (pure . (+ amount))

-- 壊れた送金: 引いてから足すまでに、別の読み取りが入ると合計がずれる
-- (ここでは「途中で合計を観測する」ことで、不整合を検出します)
totalBalance :: Bank -> IO Int
totalBalance (Bank a b) = (+) <$> readMVar a <*> readMVar b

-- 送金がすべて終わったあとなら、合計は必ず保存される
prop_transferPreservesTotal :: Property
prop_transferPreservesTotal =
  forAll (listOf (choose (1, 100))) $ \amounts -> ioProperty $ do
    bank <- newBank 1000 1000
    before <- totalBalance bank
    runConcurrently [ transfer bank amt | amt <- amounts ]
    after <- totalBalance bank
    pure (counterexample (show (before, after, amounts)) (before === after))

------------------------------------------------------------
-- 並行実行の順序に依存しない操作かを確かめる
------------------------------------------------------------
-- 「順番を入れ替えても結果が同じ」なら、並行にしても安全 (可換)
prop_incrementsCommute :: Property
prop_incrementsCommute =
  forAll (listOf (choose (-10, 10))) $ \deltas -> ioProperty $ do
    r1 <- newIORef (0 :: Int)
    mapM_ (\d -> atomicModifyIORef' r1 (\v -> (v + d, ()))) deltas
    v1 <- readIORef r1

    r2 <- newIORef (0 :: Int)
    mapM_ (\d -> atomicModifyIORef' r2 (\v -> (v + d, ()))) (reverse deltas)
    v2 <- readIORef r2

    pure (v1 === v2)

main :: IO ()
main = do
  putStrLn "--- unsafe counter (read / yield / write) ---"
  quickCheckWith stdArgs { maxSuccess = 30 } prop_unsafeCounter
  putStrLn ""

  putStrLn "--- atomicModifyIORef' ---"
  quickCheckWith stdArgs { maxSuccess = 30 } prop_atomicCounter
  putStrLn ""

  putStrLn "--- MVar ---"
  quickCheckWith stdArgs { maxSuccess = 30 } prop_mvarCounter
  putStrLn ""

  putStrLn "--- transfers preserve the total ---"
  quickCheckWith stdArgs { maxSuccess = 30 } prop_transferPreservesTotal
  putStrLn ""

  putStrLn "--- increments commute ---"
  quickCheck prop_incrementsCommute

-- 並行テストの現実:
--
--   1. 再現性がない。
--      同じテストが 100 回に 1 回しか落ちないことがあります。
--      maxSuccess を大きくして、長時間回すしかありません。
--
--   2. 「起こりうる最悪のスケジュール」を再現する工夫が要ります。
--      * yield を挟む (この Example の方法)
--      * threadDelay を挟む
--      * -threaded + 複数コアで実行する
--      * dejafu のような、スケジュールを網羅するライブラリを使う
--
--   3. 検出しやすいのは「不変条件が壊れる」タイプです。
--      合計が保存される、件数が一致する、といった性質を書いてください。
--
--   4. 本格的にやるなら「線形化可能性 (linearizability)」を検査します。
--      並行に実行したコマンド列の結果が、
--      「何らかの逐次実行順」で説明できるかを調べる手法です。
--      quickcheck-state-machine の並列テストがこれにあたります。
--
-- Example 88 の state machine テストを並行版に拡張するとこうなります:
--   1. コマンド列を2本 (または3本) 生成する
--   2. それぞれ別スレッドで実行し、観測結果を記録する
--   3. 2本を「交互に並べ替えた」すべての逐次実行を試す
--   4. どれか1つでも観測結果に一致すれば OK、しなければ失敗
--
-- 交互の並べ替えは組み合わせ爆発するので、列は短く (3〜5個) 保ちます。
