-- Example 86: 結果をプログラムから扱う
--
-- quickCheck は結果を表示するだけですが、
-- quickCheckResult は Result 型を返します。
-- テストランナーを自作したり、CI の終了コードを制御したりできます。
--
-- 実行: runghc Example86.hs
module Main (main) where

import System.Exit (exitFailure, exitSuccess)
import Test.QuickCheck

------------------------------------------------------------
-- Result の構造
------------------------------------------------------------
--   Success  { numTests, numDiscarded, labels, classes, tables, output }
--   Failure  { numTests, numShrinks, usedSeed, usedSize, reason,
--              theException, failingTestCase, failingLabels, failingClasses, output }
--   GaveUp   { numTests, numDiscarded, labels, ... }
--   NoExpectedFailure { ... }
--
-- isSuccess :: Result -> Bool  で成否だけ取れます。

prop_ok :: [Int] -> Bool
prop_ok xs = reverse (reverse xs) == xs

prop_bad :: [Int] -> Bool
prop_bad xs = length xs < 5

prop_giveUp :: [Int] -> Property
prop_giveUp xs = sum xs == 12345 ==> True

------------------------------------------------------------
-- 自作のテストランナー
------------------------------------------------------------
data NamedProp = forall p. Testable p => NamedProp String p

runAll :: [NamedProp] -> IO Bool
runAll ps = do
  results <- mapM runOne ps
  let failed = [ n | (n, False) <- results ]
  putStrLn ""
  putStrLn ("  total  : " ++ show (length results))
  putStrLn ("  passed : " ++ show (length results - length failed))
  putStrLn ("  failed : " ++ show (length failed))
  mapM_ (\n -> putStrLn ("    - " ++ n)) failed
  pure (null failed)
  where
    runOne (NamedProp name p) = do
      r <- quickCheckWithResult stdArgs { chatty = False } p
      putStrLn (pad 22 name ++ summarise r)
      pure (name, isSuccess r)
    pad n s = s ++ replicate (n - length s) ' '

summarise :: Result -> String
summarise r = case r of
  Success { numTests = n, numDiscarded = d } ->
    "PASS  (" ++ show n ++ " tests" ++ discardNote d ++ ")"
  Failure { numTests = n, numShrinks = sh, failingTestCase = tc, reason = why } ->
    "FAIL  (after " ++ show n ++ " tests, " ++ show sh ++ " shrinks)"
      ++ "\n                      reason: " ++ why
      ++ "\n                      input : " ++ unwords (map oneLine tc)
  GaveUp { numTests = n, numDiscarded = d } ->
    "GAVEUP (" ++ show n ++ " tests, " ++ show d ++ " discarded)"
  NoExpectedFailure { numTests = n } ->
    "NO EXPECTED FAILURE (" ++ show n ++ " tests)"
  where
    discardNote 0 = ""
    discardNote d = ", " ++ show d ++ " discarded"
    oneLine = takeWhile (/= '\n')

------------------------------------------------------------
-- 失敗した入力を取り出して、あとで使う
------------------------------------------------------------
captureCounterexample :: Testable p => p -> IO (Maybe [String])
captureCounterexample p = do
  r <- quickCheckWithResult stdArgs { chatty = False } p
  pure (case r of
          Failure { failingTestCase = tc } -> Just tc
          _                                -> Nothing)

------------------------------------------------------------
-- 使ったシードを記録する
------------------------------------------------------------
reportSeed :: Testable p => p -> IO ()
reportSeed p = do
  r <- quickCheckWithResult stdArgs { chatty = False } p
  case r of
    Failure { usedSeed = seed, usedSize = sz } -> do
      putStrLn ("  failed with seed = " ++ show seed)
      putStrLn ("  and size         = " ++ show sz)
      putStrLn "  reproduce with: replay = Just (<that seed>, <that size>)"
    _ -> putStrLn "  passed"

main :: IO ()
main = do
  putStrLn "--- a hand written test runner ---"
  ok <- runAll
    [ NamedProp "reverse . reverse" prop_ok
    , NamedProp "length < 5"        prop_bad
    , NamedProp "sum == 12345"      prop_giveUp
    , NamedProp "arithmetic"        (\x y -> (x :: Int) + y == y + x)
    ]
  putStrLn ""

  putStrLn "--- capturing the counterexample ---"
  ce <- captureCounterexample prop_bad
  putStrLn ("  counterexample: " ++ show ce)
  putStrLn ""

  putStrLn "--- recording the seed for reproduction ---"
  reportSeed prop_bad
  putStrLn ""

  putStrLn ("--- overall result: " ++ (if ok then "PASS" else "FAIL") ++ " ---")
  putStrLn "  (a real test executable would exit here)"
  if ok then exitSuccess' else exitFailure'
  where
    -- この Example では実際には終了しません (後続の説明を表示するため)
    exitSuccess' = pure ()
    exitFailure' = pure ()

-- 実際の test-suite では、最後をこうします:
--
--   main :: IO ()
--   main = do
--     ok <- runAll allProps
--     if ok then exitSuccess else exitFailure
--
-- cabal の exitcode-stdio-1.0 テストは、終了コードで成否を判断します。
-- Ch9 でプロジェクトに組み込みます。
--
-- Result から取れる主な情報:
--   isSuccess        成否
--   numTests         実行したテスト数
--   numShrinks       縮小の回数
--   failingTestCase  反例 (各引数の show を並べた [String])
--   reason           失敗理由の文字列
--   theException     例外が出た場合はそれ
--   usedSeed/usedSize 再現に使う情報
--   labels/classes/tables  classify や tabulate の集計結果
--
-- labels や tables を取り出せるので、
-- 「カバレッジのレポートを自分で整形して出す」ようなことも可能です。
