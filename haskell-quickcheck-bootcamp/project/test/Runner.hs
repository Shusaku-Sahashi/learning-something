-- | 小さなテストランナー。
--
-- QuickCheck だけで exitcode-stdio-1.0 のテストを書くための足場です。
-- tasty や hspec を使う場合は不要ですが、追加の依存を持ちたくないときに便利です。
{-# LANGUAGE ExistentialQuantification #-}
module Runner
  ( Prop (..)
  , Group (..)
  , runGroups
  , devArgs
  , ciArgs
  , nightlyArgs
  ) where

import System.Exit (exitFailure, exitSuccess)
import Test.QuickCheck

-- | 名前つきのプロパティ。
data Prop = forall p. Testable p => Prop String p

-- | プロパティのまとまり。
data Group = Group String [Prop]

-- | 実行プロファイル。
--
--   開発中は速く、CI では多め、夜間バッチではたっぷり回す。
--   数字を1箇所にまとめておくと、あとで調整しやすくなります。
devArgs, ciArgs, nightlyArgs :: Args
devArgs     = stdArgs { maxSuccess = 100,   maxSize = 100 }
ciArgs      = stdArgs { maxSuccess = 1000,  maxSize = 100 }
nightlyArgs = stdArgs { maxSuccess = 50000, maxSize = 300 }

runGroups :: Args -> [Group] -> IO ()
runGroups args groups = do
  results <- mapM (runGroup args) groups
  let total  = sum (map fst results)
      failed = concatMap snd results
  putStrLn ""
  putStrLn (replicate 60 '=')
  putStrLn ("  properties : " ++ show total)
  putStrLn ("  failed     : " ++ show (length failed))
  mapM_ (\n -> putStrLn ("    - " ++ n)) failed
  putStrLn (replicate 60 '=')
  if null failed then exitSuccess else exitFailure

runGroup :: Args -> Group -> IO (Int, [String])
runGroup args (Group title props) = do
  putStrLn ""
  putStrLn ("-- " ++ title ++ " " ++ replicate (max 0 (56 - length title)) '-')
  outcomes <- mapM (runProp args title) props
  pure (length props, [ n | (n, False) <- outcomes ])

runProp :: Args -> String -> Prop -> IO (String, Bool)
runProp args title (Prop name p) = do
  putStr ("  " ++ pad 34 name)
  r <- quickCheckWithResult args { chatty = False } p
  if isSuccess r
    then do
      putStrLn ("ok   " ++ shortSummary r)
      pure (title ++ "." ++ name, True)
    else do
      putStrLn "FAIL"
      putStrLn (indent (output r))
      pure (title ++ "." ++ name, False)
  where
    pad n s = s ++ replicate (n - length s) ' '
    indent = unlines . map ("      " ++) . lines

shortSummary :: Result -> String
shortSummary r = case r of
  Success { numTests = n, numDiscarded = 0 } -> "(" ++ show n ++ ")"
  Success { numTests = n, numDiscarded = d } -> "(" ++ show n ++ ", " ++ show d ++ " discarded)"
  _                                          -> ""
