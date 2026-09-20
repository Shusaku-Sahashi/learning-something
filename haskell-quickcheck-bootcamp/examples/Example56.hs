-- Example 56: 縮小をデバッグする
--
-- 「反例が縮まらない」「縮小が遅い」ときの調べ方です。
--
-- 実行: runghc Example56.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- verboseShrinking :: Testable prop => prop -> Property
--   縮小の各ステップを表示します。
------------------------------------------------------------
prop_shortList :: [Int] -> Bool
prop_shortList xs = length xs < 4

------------------------------------------------------------
-- maxShrinks: 縮小の回数を制限する
------------------------------------------------------------
newtype Slow = Slow Int
  deriving (Show, Eq)

instance Arbitrary Slow where
  arbitrary = Slow <$> choose (0, 500)
  shrink (Slow n) = [ Slow (n - 1) | n > 0 ]     -- 1 ずつしか縮まない

prop_slow :: Slow -> Bool
prop_slow (Slow n) = n < 50

------------------------------------------------------------
-- 縮小が効いていないときのチェックリスト
------------------------------------------------------------
-- (1) そもそも shrink が定義されているか
newtype Forgot = Forgot Int
  deriving (Show, Eq)

instance Arbitrary Forgot where
  arbitrary = Forgot <$> choose (0, 500)
  -- shrink を書き忘れている (デフォルトは常に [])

prop_forgot :: Forgot -> Bool
prop_forgot (Forgot n) = n < 50

-- (2) shrink が空を返していないか
checkShrinkIsUseful :: (Arbitrary a, Show a) => Gen a -> IO ()
checkShrinkIsUseful gen = do
  xs <- sequence (replicate 20 (generate gen))
  let counts = map (length . shrink) xs
  putStrLn ("  shrink candidate counts: " ++ show counts)
  putStrLn ("  all empty? " ++ show (all (== 0) counts))

-- (3) forAll を使っていないか (forAll は縮小しない)
prop_forAllNoShrink :: Property
prop_forAllNoShrink = forAll (choose (0, 500 :: Int)) (< 50)

prop_forAllShrinkOk :: Property
prop_forAllShrinkOk = forAllShrink (choose (0, 500 :: Int)) shrink (< 50)

main :: IO ()
main = do
  putStrLn "--- verboseShrinking: every shrink step is shown ---"
  quickCheckWith stdArgs { maxSuccess = 30 } (verboseShrinking prop_shortList)
  putStrLn ""

  putStrLn "--- a slow shrink: many steps ---"
  quickCheck prop_slow
  putStrLn ""

  putStrLn "--- capping it with maxShrinks ---"
  quickCheckWith stdArgs { maxShrinks = 5 } prop_slow
  putStrLn "  ^ stopped early, so the counterexample is not minimal"
  putStrLn ""

  putStrLn "--- checklist (1): shrink was never defined ---"
  quickCheck prop_forgot
  putStrLn ""

  putStrLn "--- checklist (2): is shrink returning anything at all? ---"
  putStrLn "Forgot:"
  checkShrinkIsUseful (arbitrary :: Gen Forgot)
  putStrLn "Slow:"
  checkShrinkIsUseful (arbitrary :: Gen Slow)
  putStrLn "Int:"
  checkShrinkIsUseful (arbitrary :: Gen Int)
  putStrLn ""

  putStrLn "--- checklist (3): forAll does not shrink ---"
  putStr "forAll       : " >> quickCheck prop_forAllNoShrink
  putStr "forAllShrink : " >> quickCheck prop_forAllShrinkOk

-- verboseShrinking の出力の読み方:
--
--   Failed:            <- この候補も失敗した。採用して次へ進む
--   [0,0,0,0]
--
--   Passed:            <- この候補は成功した。捨てて次の候補へ
--   []
--
-- 「Failed が全然出ない」= 候補がすべて成功している
--   -> shrink の候補が「小さすぎる」か、性質が特殊すぎる (Example 55 の局所最小)
--
-- 「そもそも何も出ない」= shrink が [] を返している
--   -> shrink を定義し忘れているか、forAll を使っている
--
-- デバッグの手順:
--   1. shrink myValue を GHCi で直接呼んで、候補が出るか見る
--   2. verboseShrinking で縮小の過程を見る
--   3. x `notElem` shrink x のプロパティを書く (Example 53)
--   4. all valid (shrink x) のプロパティを書く (Example 52)
