-- Example 85: 失敗を再現する (replay とシード)
--
-- 「CI では落ちたのに、手元では再現しない」を解決します。
--
-- 実行: runghc Example85.hs
module Main (main) where

import Test.QuickCheck
import Test.QuickCheck.Gen (unGen)
import Test.QuickCheck.Random (QCGen, mkQCGen)

------------------------------------------------------------
-- replay :: Maybe (QCGen, Int)
--   乱数生成器と初期サイズを固定します。
--   同じ値を渡せば、まったく同じ入力列が生成されます。
------------------------------------------------------------

prop_someProperty :: [Int] -> Bool
prop_someProperty xs = sum xs /= 42

runWithSeed :: Int -> IO Result
runWithSeed seed =
  quickCheckWithResult
    stdArgs { replay = Just (mkQCGen seed, 0), chatty = False }
    prop_someProperty

describe :: Result -> String
describe r = case r of
  Success { numTests = n }              -> "passed " ++ show n
  Failure { numTests = n, failingTestCase = tc } ->
    "FAILED after " ++ show n ++ ": " ++ unwords (map oneLine tc)
  GaveUp { numTests = n }               -> "gave up after " ++ show n
  NoExpectedFailure { }                 -> "no expected failure"
  where oneLine = takeWhile (/= '\n')

main :: IO ()
main = do
  putStrLn "--- the same seed always gives the same result ---"
  mapM_ (\s -> do
           r1 <- runWithSeed s
           r2 <- runWithSeed s
           putStrLn ("  seed " ++ pad 6 (show s) ++ describe r1)
           putStrLn ("  seed " ++ pad 6 (show s) ++ describe r2)
           putStrLn ("  identical? " ++ show (describe r1 == describe r2)))
        [1, 7]
  putStrLn ""

  putStrLn "--- different seeds explore different inputs ---"
  mapM_ (\s -> do
           r <- runWithSeed s
           putStrLn ("  seed " ++ pad 6 (show s) ++ describe r))
        [1 .. 12]
  putStrLn ""

  putStrLn "--- the generated values are identical for a fixed seed ---"
  -- unGen :: Gen a -> QCGen -> Int -> a
  --   生成器を「乱数生成器 + サイズ」に適用して、値を直接取り出します。
  let gen  = vectorOf 8 (arbitrary :: Gen Int)
      xs1  = unGen gen (mkQCGen 2024) 30
      xs2  = unGen gen (mkQCGen 2024) 30
      xs3  = unGen gen (mkQCGen 2025) 30
      xs4  = unGen gen (mkQCGen 2024) 5    -- サイズを変えると結果も変わる
  putStrLn ("  seed 2024, size 30 (1st): " ++ show xs1)
  putStrLn ("  seed 2024, size 30 (2nd): " ++ show xs2)
  putStrLn ("  same?                    " ++ show (xs1 == xs2))
  putStrLn ("  seed 2025, size 30      : " ++ show xs3)
  putStrLn ("  seed 2024, size  5      : " ++ show xs4)
  putStrLn ""

  putStrLn "--- recovering the seed from a failing run ---"
  putStrLn "  QuickCheck prints 'Use --quickcheck-replay=... ' only with tasty/hspec."
  putStrLn "  With plain QuickCheck, set the seed yourself:"
  putStrLn "    quickCheckWith stdArgs { replay = Just (mkQCGen 42, 0) } prop"
  putStrLn "  and record the number you used."
  where
    pad n s = s ++ replicate (n - length s) ' '

-- 実務での再現手順:
--
--   1. テストコードで replay を固定できるようにしておく
--
--        main = do
--          seed <- maybe randomSeed read <$> lookupEnv "QC_SEED"
--          quickCheckWith stdArgs { replay = Just (mkQCGen seed, 0) } prop
--
--   2. CI のログに使ったシードを必ず出力する
--
--        putStrLn ("QC_SEED=" ++ show seed)
--
--   3. 落ちたら、そのシードを環境変数で渡して手元で再現する
--
--        QC_SEED=123456 cabal test
--
-- これだけで「CI でだけ落ちる」問題の大半が解決します。
--
-- もう1つの方法は「見つかった反例を固定テストとして残す」ことです。
-- こちらのほうが確実です。Example 98 で扱います。
--
-- 注意:
--   シードが同じでも、プロパティのコードや生成器を変えると、
--   生成される入力は変わります。
--   「あのときの反例」を永続的に残したいなら、値そのものを書き留めてください。
--
--   また、上の実験で分かるとおり、同じシードでも「サイズ」が違えば
--   生成される値は変わります。replay が (QCGen, Int) のペアなのはそのためです。
