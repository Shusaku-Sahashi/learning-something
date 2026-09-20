-- Example 93: プロジェクトに組み込む
--
-- ここから Ch9「実プロジェクトでの運用」です。
-- この Example のコードは、同梱の ../project ディレクトリを1ファイルに凝縮したものです。
-- 実物は ../project で cabal test を実行して確かめてください。
--
-- 実行: runghc Example93.hs
{-# LANGUAGE ExistentialQuantification #-}
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 推奨するディレクトリ構成
------------------------------------------------------------
--   myproject/
--   ├── myproject.cabal
--   ├── src/
--   │   └── MyLib/
--   │       ├── Queue.hs
--   │       └── Text.hs
--   └── test/
--       ├── Spec.hs            エントリポイント
--       ├── Runner.hs          テストランナー (または tasty/hspec)
--       ├── Gen/               生成器を置く。複数のプロパティから使い回す
--       │   └── Queue.hs
--       └── Props/             プロパティ本体。src のモジュールに対応させる
--           ├── Queue.hs
--           ├── Text.hs
--           └── Regression.hs  過去の反例を固定したテスト
--
-- cabal ファイルの test-suite はこうなります:
--
--   test-suite spec
--       type:             exitcode-stdio-1.0
--       main-is:          Spec.hs
--       other-modules:    Gen.Queue, Props.Queue, Props.Text, Props.Regression, Runner
--       hs-source-dirs:   test
--       build-depends:    base, QuickCheck, myproject
--       default-language: Haskell2010
--
-- exitcode-stdio-1.0 は「実行ファイルを走らせ、終了コード 0 なら成功」という方式です。
-- QuickCheck だけで完結でき、追加のテストフレームワークが要りません。

------------------------------------------------------------
-- 最小のテストランナー (実物は ../project/test/Runner.hs)
------------------------------------------------------------
data Prop = forall p. Testable p => Prop String p

data Group = Group String [Prop]

runGroups :: Args -> [Group] -> IO Bool
runGroups args groups = do
  results <- mapM (runGroup args) groups
  let total  = sum (map fst results)
      failed = concatMap snd results
  putStrLn ""
  putStrLn (replicate 56 '=')
  putStrLn ("  properties : " ++ show total)
  putStrLn ("  failed     : " ++ show (length failed))
  mapM_ (\n -> putStrLn ("    - " ++ n)) failed
  putStrLn (replicate 56 '=')
  pure (null failed)

runGroup :: Args -> Group -> IO (Int, [String])
runGroup args (Group title props) = do
  putStrLn ""
  putStrLn ("-- " ++ title ++ " " ++ replicate (max 0 (50 - length title)) '-')
  outcomes <- mapM (runProp args title) props
  pure (length props, [ n | (n, False) <- outcomes ])

runProp :: Args -> String -> Prop -> IO (String, Bool)
runProp args title (Prop name p) = do
  putStr ("  " ++ pad 30 name)
  r <- quickCheckWithResult args { chatty = False } p
  if isSuccess r
    then putStrLn "ok" >> pure (title ++ "." ++ name, True)
    else do
      putStrLn "FAIL"
      putStrLn (unlines (map ("      " ++) (lines (output r))))
      pure (title ++ "." ++ name, False)
  where pad n s = s ++ replicate (n - length s) ' '

------------------------------------------------------------
-- 対象のコード (本来は src/ にある)
------------------------------------------------------------
chunksOf :: Int -> [a] -> [[a]]
chunksOf n xs
  | n <= 0    = []
  | null xs   = []
  | otherwise = take n xs : chunksOf n (drop n xs)

ellipsis :: Int -> String -> String
ellipsis n s
  | n <= 0        = ""
  | length s <= n = s
  | n <= 3        = take n s
  | otherwise     = take (n - 3) s ++ "..."

------------------------------------------------------------
-- プロパティ (本来は test/Props/ にある)
------------------------------------------------------------
textGroup :: Group
textGroup = Group "MyLib.Text"
  [ Prop "chunksOf round trip"  prop_chunksConcat
  , Prop "chunksOf no empties"  prop_chunksNonEmpty
  , Prop "ellipsis bounded"     prop_ellipsisBounded
  , Prop "ellipsis idempotent"  prop_ellipsisIdempotent
  ]

prop_chunksConcat :: Positive Int -> [Int] -> Property
prop_chunksConcat (Positive n) xs = concat (chunksOf n xs) === xs

prop_chunksNonEmpty :: Positive Int -> [Int] -> Bool
prop_chunksNonEmpty (Positive n) xs = all (not . null) (chunksOf n xs)

prop_ellipsisBounded :: NonNegative Int -> String -> Property
prop_ellipsisBounded (NonNegative n) s =
  counterexample (show (ellipsis n s)) (length (ellipsis n s) <= n)

prop_ellipsisIdempotent :: NonNegative Int -> String -> Property
prop_ellipsisIdempotent (NonNegative n) s =
  ellipsis n (ellipsis n s) === ellipsis n s

------------------------------------------------------------
-- わざと失敗するグループ (出力の見え方を確認する)
------------------------------------------------------------
brokenGroup :: Group
brokenGroup = Group "Broken"
  [ Prop "this one fails" (\xs -> length (xs :: [Int]) < 3) ]

main :: IO ()
main = do
  putStrLn "=== all green ==="
  ok1 <- runGroups stdArgs [textGroup]
  putStrLn ("  exit code would be " ++ show (if ok1 then 0 else 1 :: Int))
  putStrLn ""

  putStrLn "=== with a failing group ==="
  ok2 <- runGroups stdArgs [textGroup, brokenGroup]
  putStrLn ("  exit code would be " ++ show (if ok2 then 0 else 1 :: Int))

-- 本物の Spec.hs はこう終わります:
--
--   main :: IO ()
--   main = do
--     ok <- runGroups args allGroups
--     if ok then exitSuccess else exitFailure
--
-- ★ tasty や hspec を使う場合
--
--   自前のランナーは「依存を増やしたくない」ときの選択肢です。
--   実務では tasty + tasty-quickcheck を使うことが多く、
--   そのほうが便利な点もあります:
--
--     * --quickcheck-replay=... が失敗時に表示され、そのまま再現できる
--     * --quickcheck-tests=N でテスト数をコマンドラインから変えられる
--     * -p パターンで特定のテストだけ実行できる
--     * 並列実行、タイムアウト、カラー出力が最初から付いている
--
--   build-depends に tasty, tasty-quickcheck を足すだけで移行できます。
