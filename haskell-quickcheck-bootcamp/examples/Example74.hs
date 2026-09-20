-- Example 74: cover で「最低これだけは試せ」を強制する
--
-- classify は「見るだけ」でした。
-- cover は「割合が足りなければテストを失敗させる」ことができます。
--
-- 実行: runghc Example74.hs
module Main (main) where

import Test.QuickCheck

-- cover :: Testable prop => Double -> Bool -> String -> prop -> Property
--   第1引数: 最低限の割合 (%)
--   第2引数: 条件
--   第3引数: ラベル

------------------------------------------------------------
-- 満たされる場合
------------------------------------------------------------
prop_coverOk :: Int -> Property
prop_coverOk n =
  cover 30 (n > 0)  "positive" $
  cover 30 (n < 0)  "negative" $
    n == n

------------------------------------------------------------
-- 満たされない場合: 警告が出る
------------------------------------------------------------
prop_coverInsufficient :: [Int] -> Property
prop_coverInsufficient xs =
  cover 50 (length xs > 50) "very long list" $
    reverse (reverse xs) == xs

------------------------------------------------------------
-- 実用例: 重要な分岐のカバレッジを保証する
------------------------------------------------------------
data Account = Account { balance :: Int, frozen :: Bool }
  deriving (Show)

instance Arbitrary Account where
  arbitrary = Account <$> choose (-10000, 100000) <*> frequency [(9, pure False), (1, pure True)]

-- 注: Result という名前は Test.QuickCheck が既に使っているので、
--     別名にします (衝突すると Ambiguous occurrence になります)。
data Outcome = Ok Int | Insufficient | Frozen
  deriving (Show, Eq)

withdraw :: Int -> Account -> Outcome
withdraw amount acct
  | frozen acct            = Frozen
  | balance acct < amount  = Insufficient
  | otherwise              = Ok (balance acct - amount)

-- 「3つの結果すべてが、それなりの割合で出ている」ことを保証する
prop_withdrawCovered :: Positive Int -> Account -> Property
prop_withdrawCovered (Positive amount) acct =
  let r = withdraw amount acct
  in cover 5  (r == Frozen)       "frozen"       $
     cover 20 (r == Insufficient) "insufficient" $
     cover 20 (isOk r)            "ok"           $
       resultIsSane r
  where
    isOk (Ok _) = True
    isOk _      = False
    resultIsSane (Ok b) = b >= 0
    resultIsSane _      = True

------------------------------------------------------------
-- cover が足りないと言ってきたら、生成器を直す
------------------------------------------------------------
-- 上の prop_withdrawCovered は "insufficient" が 10% 前後しか出ません。
-- 引き出し額 (Positive Int は小さい値に寄る) に対して
-- 残高 (最大 100000) が大きすぎるからです。
-- 「残高に応じた引き出し額」を生成すれば、3つの結果がバランスします。
genAccountAndAmount :: Gen (Account, Int)
genAccountAndAmount = do
  acct   <- arbitrary
  amount <- frequency
    [ (1, choose (1, 100))                                  -- 小さい額
    , (2, choose (1, max 1 (balance acct)))                 -- 残高以下
    , (2, choose (max 1 (balance acct), max 1 (balance acct) + 10000))  -- 残高超え
    ]
  pure (acct, amount)

prop_withdrawCoveredFixed :: Property
prop_withdrawCoveredFixed =
  forAll genAccountAndAmount $ \(acct, amount) ->
    let r = withdraw amount acct
    in cover 5  (r == Frozen)       "frozen"       $
       cover 20 (r == Insufficient) "insufficient" $
       cover 20 (isOk r)            "ok"           $
         resultIsSane r
  where
    isOk (Ok _) = True
    isOk _      = False
    resultIsSane (Ok b) = b >= 0
    resultIsSane _      = True

------------------------------------------------------------
-- cover が守ってくれるもの: 生成器の劣化を検出する
------------------------------------------------------------
-- もし誰かが Account の生成器を
--   arbitrary = Account <$> choose (100000, 200000) <*> pure False
-- のように変えてしまったら、"insufficient" が 0% になり、
-- cover がテストを失敗させます。
--
-- 「テストは全部通っているが、実は何も試していない」
-- という最悪の状態を、機械的に防げます。

main :: IO ()
main = do
  putStrLn "--- cover satisfied ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_coverOk
  putStrLn ""

  putStrLn "--- cover not satisfied (warning appears) ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_coverInsufficient
  putStrLn ""

  putStrLn "--- realistic: all three outcomes must appear ---"
  quickCheckWith stdArgs { maxSuccess = 2000 } prop_withdrawCovered
  putStrLn "  ^ 'insufficient' is under target: the generator needs fixing"
  putStrLn ""

  putStrLn "--- after correlating the amount with the balance ---"
  quickCheckWith stdArgs { maxSuccess = 2000 } prop_withdrawCoveredFixed

-- 出力の読み方:
--
--   +++ OK, passed 1000 tests (0.0% very long list).
--
--   Only 0.0% very long list, but expected 50.0%
--
-- 「通ったが、カバレッジが足りない」という警告です。
-- 既定では「警告を出すだけ」で、テストは成功扱いです。
--
-- これを「失敗」にしたい場合は checkCoverage を使います (Example 75)。
--
-- cover を書くべき場所:
--   * 重要な分岐 (エラー処理、境界値、特殊ケース)
--   * 「めったに起きないが、起きたら致命的」なケース
--   * 生成器を書き換えたときに壊れやすいところ
--
-- 割合の決め方:
--   実際に classify で測ってから、その 1/2 〜 2/3 くらいを下限にします。
--   厳しすぎると、たまたま偏った実行で落ちてしまいます。
--
-- ★ この Example の本題は、上の2つの実行結果の差です。
--   独立に生成した (残高, 引き出し額) では "insufficient" が 1割弱。
--   残高に応じた額を生成すると、3つの結果がバランスします。
--   「入力同士の相関」を意識しないと、特定の分岐に到達できません。
