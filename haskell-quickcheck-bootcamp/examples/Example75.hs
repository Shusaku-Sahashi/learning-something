-- Example 75: checkCoverage でカバレッジ不足を失敗にする
--
-- cover は警告を出すだけでした。
-- checkCoverage を付けると、統計的に「足りない」と判断された時点で失敗します。
--
-- 実行: runghc Example75.hs
module Main (main) where

import Test.QuickCheck

-- checkCoverage :: Testable prop => prop -> Property
--   * カバレッジが十分か、統計的仮説検定で判定する
--   * 判定がつくまで、テスト回数を自動で増やす
--   * 不足が確定したら失敗させる

------------------------------------------------------------
-- 足りているケース: テスト回数が自動で調整される
------------------------------------------------------------
prop_enough :: Int -> Property
prop_enough n =
  checkCoverage $
  cover 40 (n > 0) "positive" $
    n == n

------------------------------------------------------------
-- 足りないケース: 失敗する
------------------------------------------------------------
prop_notEnough :: [Int] -> Property
prop_notEnough xs =
  checkCoverage $
  cover 50 (length xs > 30) "long list" $
    reverse (reverse xs) == xs

------------------------------------------------------------
-- 実用例: 生成器の品質を CI で守る
------------------------------------------------------------
data Token = TNum Int | TIdent String | TOp Char | TParen Bool
  deriving (Show, Eq)

-- 良い生成器
genTokenGood :: Gen Token
genTokenGood = frequency
  [ (3, TNum <$> choose (0, 999))
  , (3, TIdent <$> listOf1 (elements ['a' .. 'z']))
  , (3, TOp <$> elements "+-*/")
  , (2, TParen <$> arbitrary)
  ]

-- 劣化した生成器 (誰かが「簡単にしよう」として壊した想定)
genTokenDegraded :: Gen Token
genTokenDegraded = frequency
  [ (97, TNum <$> choose (0, 9))
  , (1,  TIdent <$> pure "x")
  , (1,  TOp <$> pure '+')
  , (1,  TParen <$> pure True)
  ]

isNum, isIdent, isOp, isParen :: Token -> Bool
isNum   (TNum _)   = True
isNum   _          = False
isIdent (TIdent _) = True
isIdent _          = False
isOp    (TOp _)    = True
isOp    _          = False
isParen (TParen _) = True
isParen _          = False

render :: Token -> String
render (TNum n)     = show n
render (TIdent s)   = s
render (TOp c)      = [c]
render (TParen b)   = if b then "(" else ")"

coverageGuard :: Gen Token -> Property
coverageGuard gen =
  checkCoverage $
  forAll gen $ \t ->
    cover 15 (isNum t)   "number"     $
    cover 15 (isIdent t) "identifier" $
    cover 15 (isOp t)    "operator"   $
    cover 10 (isParen t) "paren"      $
      not (null (render t))

main :: IO ()
main = do
  putStrLn "--- coverage is sufficient (note the test count grows) ---"
  quickCheck prop_enough
  putStrLn ""

  putStrLn "--- coverage is insufficient: this FAILS ---"
  quickCheck prop_notEnough
  putStrLn ""

  putStrLn "--- guarding a good generator: passes ---"
  quickCheck (coverageGuard genTokenGood)
  putStrLn ""

  putStrLn "--- guarding a degraded generator: FAILS ---"
  quickCheck (coverageGuard genTokenDegraded)

-- checkCoverage の挙動:
--
--   1. まず maxSuccess 回テストする
--   2. カバレッジが十分かを統計的に判定する
--   3. 判定がつかなければ、テスト回数を倍にして繰り返す
--   4. 「明らかに足りない」と確定したら失敗させる
--
-- だから出力のテスト回数が 100 ではなく 400 や 1600 になることがあります。
-- これは正常な動作です。
--
-- 実務での使い方:
--
--   * 生成器を書いたら、その品質を checkCoverage + cover で固定する
--   * CI に入れておけば、生成器の劣化が自動で検出される
--   * ただし全プロパティに付けると遅くなるので、
--     「生成器ガード」として専用のプロパティを1本立てるのがおすすめです
--
--       prop_generatorCoverage :: Property
--       prop_generatorCoverage = checkCoverage $ forAll myGen $ \x ->
--         cover 20 (isCaseA x) "case A" $
--         cover 20 (isCaseB x) "case B" $
--           True
--
--   このプロパティは「対象のロジック」を一切テストしていませんが、
--   「テストの前提」を守るという重要な仕事をしています。
