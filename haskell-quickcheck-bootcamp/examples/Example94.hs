-- Example 94: 実行プロファイルとシードの管理
--
-- 「開発中は速く、CI では多めに、夜間はたっぷり」を仕組みにします。
--
-- 実行:
--   runghc Example94.hs
--   QC_PROFILE=ci runghc Example94.hs
--   QC_SEED=12345 runghc Example94.hs
module Main (main) where

import System.Environment (lookupEnv)
import Test.QuickCheck
import Test.QuickCheck.Random (mkQCGen)

------------------------------------------------------------
-- プロファイル: 数値を1箇所にまとめる
------------------------------------------------------------
devArgs, ciArgs, nightlyArgs :: Args
devArgs = stdArgs
  { maxSuccess      = 100      -- 手元では速さ優先
  , maxSize         = 100
  , maxDiscardRatio = 10
  }

ciArgs = stdArgs
  { maxSuccess      = 1000     -- PR ごとに 10 倍
  , maxSize         = 100
  , maxDiscardRatio = 10
  }

nightlyArgs = stdArgs
  { maxSuccess      = 50000    -- 夜間バッチ
  , maxSize         = 300      -- 大きい入力も試す
  , maxDiscardRatio = 20
  }

------------------------------------------------------------
-- 環境変数から組み立てる
------------------------------------------------------------
resolveArgs :: IO (Args, String)
resolveArgs = do
  profile <- lookupEnv "QC_PROFILE"
  seedStr <- lookupEnv "QC_SEED"

  let base = case profile of
        Just "ci"      -> ciArgs
        Just "nightly" -> nightlyArgs
        _              -> devArgs

      args = case seedStr of
        Just s | [(n, "")] <- reads s -> base { replay = Just (mkQCGen n, 0) }
        _                             -> base

      label = maybe "dev" id profile
                ++ maybe "" (\s -> " (seed " ++ s ++ ")") seedStr

  pure (args, label)

------------------------------------------------------------
-- プロパティごとに上書きしたいとき
------------------------------------------------------------
-- 「このプロパティだけは多めに回したい」は withMaxSuccess で書けます。
-- プロファイルより優先されます。
prop_important :: [Int] -> Property
prop_important xs = withMaxSuccess 5000 (reverse (reverse xs) === xs)

-- 「このプロパティは遅いので少なめに」も同様です。
prop_slow :: [Int] -> Property
prop_slow xs = withMaxSuccess 20 (length (expensive xs) === length xs)
  where expensive = map (\x -> sum [1 .. abs x `mod` 1000])

prop_normal :: [Int] -> Property
prop_normal xs = length (xs ++ xs) === 2 * length xs

------------------------------------------------------------
-- 「捨てすぎ」を検出して警告する
------------------------------------------------------------
runAndWarn :: Testable p => Args -> String -> p -> IO Bool
runAndWarn args name p = do
  r <- quickCheckWithResult args { chatty = False } p
  case r of
    Success { numTests = n, numDiscarded = d } -> do
      let wasted = fromIntegral d / fromIntegral (max 1 (n + d)) :: Double
      putStrLn ("  " ++ pad 22 name ++ "ok   (" ++ show n ++ " tests"
                  ++ (if d == 0 then "" else ", " ++ show d ++ " discarded") ++ ")")
      if wasted > 0.5
        then putStrLn ("      WARNING: " ++ show (round (wasted * 100) :: Int)
                         ++ "% of inputs were discarded. Fix the generator.")
        else pure ()
      pure True
    GaveUp { numTests = n, numDiscarded = d } -> do
      putStrLn ("  " ++ pad 22 name ++ "GAVE UP (" ++ show n ++ " passed, "
                  ++ show d ++ " discarded)")
      pure False
    _ -> do
      putStrLn ("  " ++ pad 22 name ++ "FAIL")
      pure False
  where pad n s = s ++ replicate (n - length s) ' '

prop_wasteful :: [Int] -> Property
prop_wasteful xs = length xs >= 10 ==> length xs >= 10

main :: IO ()
main = do
  (args, label) <- resolveArgs
  putStrLn ("profile    : " ++ label)
  putStrLn ("maxSuccess : " ++ show (maxSuccess args))
  putStrLn ("maxSize    : " ++ show (maxSize args))
  putStrLn ("replay     : " ++ (case replay args of
                                  Nothing -> "(random)"
                                  Just _  -> "(fixed)"))
  putStrLn ""

  putStrLn "--- running with the resolved profile ---"
  _ <- runAndWarn args "normal"     prop_normal
  _ <- runAndWarn args "important"  prop_important
  _ <- runAndWarn args "slow"       prop_slow
  _ <- runAndWarn args "wasteful"   prop_wasteful
  putStrLn ""

  putStrLn "--- try these ---"
  putStrLn "  QC_PROFILE=ci      runghc Example94.hs"
  putStrLn "  QC_PROFILE=nightly runghc Example94.hs"
  putStrLn "  QC_SEED=12345      runghc Example94.hs"

-- 運用のポイント:
--
--   1. 数値をコードに散らさない。
--      devArgs / ciArgs / nightlyArgs の3つにまとめる。
--
--   2. 環境変数で切り替える。
--      CI の YAML 側に QC_PROFILE: ci と書くだけで済みます。
--
--   3. シードをログに出す。
--      落ちたとき、同じシードで手元再現できます。
--
--   4. 「捨てすぎ」を機械的に警告する。
--      上の runAndWarn のように、50% を超えたら警告を出しておくと、
--      生成器の劣化に気づけます (Ch6, Ch7)。
--
--   5. 個別の上書きは withMaxSuccess で。
--      プロパティの定義のすぐそばに書けるので、意図が伝わります。
