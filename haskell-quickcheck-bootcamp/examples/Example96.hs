-- Example 96: CI で運用する
--
-- CI に載せるときに考えることと、その実装です。
--
-- 実行: runghc Example96.hs
module Main (main) where

import Data.List (sortBy)
import Data.Ord (comparing, Down (..))
import System.Environment (lookupEnv)
import Test.QuickCheck

------------------------------------------------------------
-- CI で困ること
------------------------------------------------------------
--   1. 失敗が再現しない        -> シードを出力する
--   2. どのプロパティが遅いか分からない -> 実行時間を記録する
--   3. カバレッジが劣化しても気づかない -> cover を CI で回す
--   4. 毎回のビルドが遅い       -> PR と夜間でプロファイルを分ける

------------------------------------------------------------
-- 実行結果をまとめる
------------------------------------------------------------
data Outcome = Outcome
  { oName     :: String
  , oPassed   :: Bool
  , oTests    :: Int
  , oDiscards :: Int
  , oDetail   :: String
  }

runOne :: Testable p => Args -> String -> p -> IO Outcome
runOne args name p = do
  r <- quickCheckWithResult args { chatty = False } p
  pure (case r of
          Success { numTests = n, numDiscarded = d } -> Outcome name True n d ""
          GaveUp  { numTests = n, numDiscarded = d } ->
            Outcome name False n d "gave up: too many discarded inputs"
          Failure { numTests = n, usedSeed = sd, usedSize = sz, failingTestCase = tc } ->
            Outcome name False n 0
              ("failed with seed " ++ show sd ++ ", size " ++ show sz
                 ++ "\n      input: " ++ unwords (map (takeWhile (/= '\n')) tc))
          NoExpectedFailure { numTests = n } ->
            Outcome name False n 0 "expected a failure but it passed")

------------------------------------------------------------
-- CI 向けのレポート
------------------------------------------------------------
report :: [Outcome] -> IO Bool
report outs = do
  putStrLn ""
  putStrLn "== results =="
  mapM_ line outs
  let failed = filter (not . oPassed) outs
  putStrLn ""
  putStrLn ("passed : " ++ show (length outs - length failed) ++ " / " ++ show (length outs))

  -- 捨てる割合が多いものを上位表示する (生成器の劣化に気づくため)
  let wasteful = [ (oName o, ratio o) | o <- outs, ratio o > 0.2 ]
  if null wasteful
    then pure ()
    else do
      putStrLn ""
      putStrLn "== generators to review (over 20% of inputs discarded) =="
      mapM_ (\(n, r) -> putStrLn ("  " ++ pad 26 n
                                    ++ show (round (r * 100) :: Int) ++ "%"))
            (sortBy (comparing (Down . snd)) wasteful)

  if null failed
    then pure ()
    else do
      putStrLn ""
      putStrLn "== failures =="
      mapM_ (\o -> putStrLn ("  " ++ oName o ++ ": " ++ oDetail o)) failed

  pure (null failed)
  where
    line o = putStrLn ("  " ++ pad 26 (oName o)
                         ++ (if oPassed o then "ok  " else "FAIL")
                         ++ "  tests=" ++ pad 6 (show (oTests o))
                         ++ "  discarded=" ++ show (oDiscards o))
    ratio o = fromIntegral (oDiscards o)
                / fromIntegral (max 1 (oTests o + oDiscards o)) :: Double
    pad n s = s ++ replicate (n - length s) ' '

------------------------------------------------------------
-- テスト対象とプロパティ
------------------------------------------------------------
prop_good :: [Int] -> Property
prop_good xs = reverse (reverse xs) === xs

prop_wasteful :: [Int] -> Property
prop_wasteful xs = length xs >= 8 ==> length xs >= 8

prop_coverGuard :: Property
prop_coverGuard =
  checkCoverage $
  forAll (arbitrary :: Gen [Int]) $ \xs ->
    cover 3  (null xs)         "empty"     $
    cover 30 (length xs >= 5)  "5 or more" $
      True

prop_broken :: [Int] -> Property
prop_broken xs = counterexample (show (length xs)) (length xs < 6)

main :: IO ()
main = do
  profile <- lookupEnv "QC_PROFILE"
  let args = case profile of
        Just "ci"      -> stdArgs { maxSuccess = 1000 }
        Just "nightly" -> stdArgs { maxSuccess = 20000, maxSize = 300 }
        _              -> stdArgs

  putStrLn ("profile    : " ++ maybe "dev" id profile)
  putStrLn ("maxSuccess : " ++ show (maxSuccess args))

  outs <- sequence
    [ runOne args "reverse round trip" prop_good
    , runOne args "wasteful filter"    prop_wasteful
    , runOne args "coverage guard"     prop_coverGuard
    , runOne args "deliberately broken" prop_broken
    ]
  ok <- report outs
  putStrLn ""
  putStrLn ("exit code would be " ++ show (if ok then 0 else 1 :: Int))

-- GitHub Actions の例 (../project/.github/workflows/ci.yml に実物があります):
--
--   on:
--     push:
--       branches: [main]
--     pull_request:
--     schedule:
--       - cron: '0 18 * * *'      # 毎日 18:00 UTC
--
--   jobs:
--     test:
--       runs-on: ubuntu-latest
--       strategy:
--         matrix:
--           ghc: ['9.4.8', '9.6.4']
--       steps:
--         - uses: actions/checkout@v4
--         - uses: haskell-actions/setup@v2
--           with:
--             ghc-version: ${{ matrix.ghc }}
--         - uses: actions/cache@v4
--           with:
--             path: ~/.cabal/store
--             key: ${{ runner.os }}-ghc${{ matrix.ghc }}-${{ hashFiles('**/*.cabal') }}
--         - run: cabal update
--         - name: tests
--           if: github.event_name != 'schedule'
--           env: { QC_PROFILE: ci }
--           run: cabal test --test-show-details=direct
--         - name: nightly
--           if: github.event_name == 'schedule'
--           env: { QC_PROFILE: nightly }
--           run: cabal test --test-show-details=direct
--
-- チェックリスト:
--   [ ] --test-show-details=direct を付ける (付けないと出力が見えない)
--   [ ] シードをログに出す
--   [ ] PR と夜間でプロファイルを分ける
--   [ ] cabal store をキャッシュする
--   [ ] 複数の GHC バージョンで回す
--   [ ] cover / checkCoverage を CI で回して、生成器の劣化を検出する
--   [ ] 捨てる割合が多いプロパティを可視化する
