-- Example 84: タイムアウトと性能のテスト
--
-- 「終わらないコード」「遅すぎるコード」を検出します。
--
-- 実行: runghc Example84.hs
module Main (main) where

import Data.List (sort, nub)
import Test.QuickCheck

------------------------------------------------------------
-- within :: Int -> prop -> Property
--   マイクロ秒単位のタイムアウト。超えたら失敗。
------------------------------------------------------------

-- O(n^2) の重複除去
nubSlow :: [Int] -> [Int]
nubSlow = nub

-- O(n log n) の重複除去 (順序は保たれない)
nubFast :: [Int] -> [Int]
nubFast = map head . groupSorted . sort
  where
    groupSorted []       = []
    groupSorted (x : xs) = let (same, rest) = span (== x) xs
                           in (x : same) : groupSorted rest

-- 小さい入力なら、どちらも十分速い
prop_bothFastOnSmall :: Property
prop_bothFastOnSmall =
  forAll (resize 50 (listOf (choose (0, 1000)))) $ \xs ->
    within 1000000 (length (nubSlow xs) == length (nubFast xs))

-- 大きい入力では差が出る
-- ★ ここで forAll ではなく forAllBlind を使っているのは、
--   反例として 20000 要素のリストが丸ごと画面に出るのを避けるためです。
--   代わりに counterexample で「長さ」だけ表示します (Ch5 の Blind と同じ考え方)。
prop_slowOnLarge :: Property
prop_slowOnLarge =
  forAllBlind (vectorOf 20000 (choose (0, 1000000 :: Int))) $ \xs ->
    counterexample ("input length = " ++ show (length xs)) $
      within 300000 (length (nubSlow xs) >= 0)

prop_fastOnLarge :: Property
prop_fastOnLarge =
  forAllBlind (vectorOf 20000 (choose (0, 1000000 :: Int))) $ \xs ->
    counterexample ("input length = " ++ show (length xs)) $
      within 3000000 (length (nubFast xs) >= 0)

------------------------------------------------------------
-- 無限ループの検出
------------------------------------------------------------
-- バグで停止しなくなった関数
collatzBuggy :: Int -> Int
collatzBuggy n = go n 0
  where
    go 1 steps = steps
    go k steps
      | even k    = go (k `div` 2) (steps + 1)
      | otherwise = go (3 * k + 1) (steps + 1)
    -- n <= 0 のとき停止しない

prop_collatzTerminates :: Positive Int -> Property
prop_collatzTerminates (Positive n) =
  within 1000000 (collatzBuggy n >= 0)

-- 0 以下を渡すと止まりません。within が守ってくれます。
prop_collatzAnyInt :: Int -> Property
prop_collatzAnyInt n =
  within 200000 (collatzBuggy n >= 0)

------------------------------------------------------------
-- 「計算量のオーダー」をプロパティで確かめる
------------------------------------------------------------
-- 厳密な計測はマイクロベンチマークの仕事ですが、
-- 「入力を2倍にしたら時間が4倍を超えない」程度の粗い検査はできます。
-- ここでは「ステップ数」を数えて代用します。
countStepsSlow :: [Int] -> Int
countStepsSlow xs = go xs 0
  where
    go [] acc       = acc
    go (y : ys) acc = go ys (acc + length (filter (== y) ys) + 1)

prop_quadraticGrowth :: Property
prop_quadraticGrowth =
  forAll (choose (10, 100)) $ \n ->
    let xs  = [1 .. n]
        x2s = [1 .. 2 * n]
        s1  = countStepsSlow xs
        s2  = countStepsSlow x2s
    in counterexample (show (n, s1, s2))
         (s2 <= 5 * s1)      -- 2倍の入力で、ステップ数は4倍程度に収まる

main :: IO ()
main = do
  putStr "both fast on small   : " >> quickCheck prop_bothFastOnSmall
  putStrLn ""

  putStrLn "--- nub on 20000 elements, 0.3s budget (expected to FAIL) ---"
  quickCheckWith stdArgs { maxSuccess = 1 } prop_slowOnLarge
  putStrLn ""

  putStrLn "--- sort-based version, 3s budget ---"
  quickCheckWith stdArgs { maxSuccess = 1 } prop_fastOnLarge
  putStrLn ""

  putStr "collatz on positives : " >> quickCheck prop_collatzTerminates
  putStrLn ""

  putStrLn "--- collatz on any Int: within catches the non-terminating case ---"
  quickCheck prop_collatzAnyInt
  putStrLn ""

  putStr "quadratic growth     : " >> quickCheck prop_quadraticGrowth

-- within の注意点:
--
--   1. 環境に依存します。CI のマシンが遅いと落ちます。
--      本番で使うなら、余裕を 5〜10 倍持たせてください。
--
--   2. within は「時間がかかりすぎた」ことを報告しますが、
--      すでに走っている計算を止められるとは限りません。
--      純粋な無限ループ (最適化で割り込み点が消えた場合) だと、
--      タイムアウトが効かないことがあります。
--
--   3. 縮小のたびに再実行されるので、縮小も遅くなります。
--      maxShrinks で制限するとよいでしょう。
--
-- 使いどころ:
--   * 「停止すること」を仕様に含む関数 (パーサ、正規化、再帰アルゴリズム)
--   * 性能の回帰を検出したいとき (ただし粗い網です)
--   * 無限ループを作り込みやすいコードの安全網
--
-- 本格的な性能計測には criterion などのベンチマークツールを使ってください。
-- QuickCheck の within は「明らかにおかしい」を捕まえる道具です。
