-- Example 78: 分布を直す技法カタログ
--
-- 「この分岐に届いていない」と分かったあと、どう直すか。
-- 手札をひととおり並べます。
--
-- 実行: runghc Example78.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 技法1: frequency の重みを変える
------------------------------------------------------------
data Level = Debug | Info | Warn | Error_
  deriving (Show, Eq, Enum, Bounded)

-- 現実に近い分布 (Error はめったに出ない)
genLevelRealistic :: Gen Level
genLevelRealistic = frequency [ (60, pure Debug), (30, pure Info), (8, pure Warn), (2, pure Error_) ]

-- テスト用の分布 (全部を均等に試す)
genLevelForTesting :: Gen Level
genLevelForTesting = elements [minBound .. maxBound]

------------------------------------------------------------
-- 技法2: 入力同士に相関を持たせる
------------------------------------------------------------
-- 独立に生成すると、条件を満たす組み合わせがほとんど出ない
genIndependent :: Gen (Int, Int)
genIndependent = (,) <$> choose (0, 1000) <*> choose (0, 1000)

-- 片方をもう片方から作ると、狙った関係を確実に出せる
genCorrelated :: Gen (Int, Int)
genCorrelated = do
  x <- choose (0, 1000)
  d <- choose (-10, 10)
  pure (x, x + d)        -- 「近い2値」が必ず出る

------------------------------------------------------------
-- 技法3: 境界値を明示的に混ぜる
------------------------------------------------------------
genWithBoundaries :: Gen Int
genWithBoundaries = frequency
  [ (1, elements [minBound, minBound + 1, -1, 0, 1, maxBound - 1, maxBound])
  , (4, arbitrary)
  ]

------------------------------------------------------------
-- 技法4: 「狙い撃ち生成器」を別に用意する
------------------------------------------------------------
-- 普段の生成器では出ない条件を、専用の生成器で確実に試す。
-- (Example 38 の LeapDay / MonthEnd と同じ考え方)
genSameValue :: Gen (Int, Int)
genSameValue = do
  x <- arbitrary
  pure (x, x)

------------------------------------------------------------
-- 技法5: サイズを操作する
------------------------------------------------------------
-- 長いリストが必要なら、resize / scale でサイズを上げる
genLongList :: Gen [Int]
genLongList = resize 200 (listOf arbitrary)

-- 小さい入力に集中したいなら下げる
genTinyList :: Gen [Int]
genTinyList = resize 3 (listOf arbitrary)

------------------------------------------------------------
-- 技法6: 値を「再利用」して重複を作る
------------------------------------------------------------
-- 値の範囲が広いと、リストの中に同じ値が2つ現れることは滅多にありません。
-- 「小さい候補集合から選ぶ」と、重複が自然に発生します。
--
-- 注: QuickCheck の arbitrary :: Gen Int はサイズに比例した小さい値を作るので、
--     実はそれなりに重複します。ここでは Int の全域から選んで差を見せます。
genWideRange :: Gen [Int]
genWideRange = listOf (choose (minBound, maxBound))

genWithDuplicates :: Gen [Int]
genWithDuplicates = listOf (choose (0, 5))

------------------------------------------------------------
-- 技法7: 構造を先に決めて、中身を埋める
------------------------------------------------------------
-- 「長さが同じ2つのリスト」「合計が N になる分割」など。
genSumsToN :: Int -> Gen [Int]
genSumsToN 0 = pure []
genSumsToN n = do
  k <- choose (1, n)
  rest <- genSumsToN (n - k)
  pure (k : rest)

------------------------------------------------------------
-- 効果を測る
------------------------------------------------------------
measure :: String -> Gen a -> (a -> Bool) -> IO ()
measure label gen p = do
  xs <- sequence (replicate 2000 (generate gen))
  let hits = length (filter p xs)
  putStrLn ("  " ++ pad 30 label ++ show hits ++ " / 2000")
  where pad n s = s ++ replicate (n - length s) ' '

main :: IO ()
main = do
  putStrLn "--- technique 1: weights ---"
  measure "realistic: Error"     genLevelRealistic  (== Error_)
  measure "for testing: Error"   genLevelForTesting (== Error_)
  putStrLn ""

  putStrLn "--- technique 2: correlation (|x - y| <= 10) ---"
  measure "independent"          genIndependent (\(x, y) -> abs (x - y) <= 10)
  measure "correlated"           genCorrelated  (\(x, y) -> abs (x - y) <= 10)
  putStrLn ""

  putStrLn "--- technique 3: boundaries ---"
  measure "plain arbitrary"      (arbitrary :: Gen Int) (\n -> n == 0 || n == maxBound || n == minBound)
  measure "with boundaries"      genWithBoundaries      (\n -> n == 0 || n == maxBound || n == minBound)
  putStrLn ""

  putStrLn "--- technique 4: targeted generator (x == y) ---"
  measure "independent"          genIndependent (uncurry (==))
  measure "targeted"             genSameValue   (uncurry (==))
  putStrLn ""

  putStrLn "--- technique 5: size (length >= 50) ---"
  measure "default size"         (arbitrary :: Gen [Int]) (\xs -> length xs >= 50)
  measure "resize 200"           genLongList              (\xs -> length xs >= 50)
  putStrLn ""

  putStrLn "--- technique 6: duplicates inside a list ---"
  measure "wide range (all of Int)" genWideRange   hasDup
  measure "default arbitrary"    (arbitrary :: Gen [Int]) hasDup
  measure "small value range"    genWithDuplicates hasDup
  putStrLn ""

  putStrLn "--- technique 7: build the structure first ---"
  parts <- sample' (genSumsToN 10)
  putStrLn ("  partitions of 10: " ++ show (take 6 parts))
  putStrLn ("  all sum to 10?    " ++ show (all ((== 10) . sum) parts))
  where
    hasDup xs = length xs /= length (dedup xs)
    dedup = foldr (\x acc -> if x `elem` acc then acc else x : acc) []

-- 選び方の目安:
--
--   分岐に届かない            -> 技法1 (重み) または 技法4 (狙い撃ち)
--   2つの入力の関係が必要      -> 技法2 (相関)
--   境界値でのバグを探したい   -> 技法3 (境界値の混入)
--   大きい入力が必要          -> 技法5 (サイズ)
--   重複・衝突を試したい       -> 技法6 (候補集合を小さく)
--   複雑な制約がある          -> 技法7 (構造から作る)
--
-- ★ 技法6 は見落としがちですが、非常に重要です。
--   キャッシュ、辞書、集合など「同じキーが来たとき」のバグは、
--   値の範囲が広いままだと、まず出ません。
--
--   上の測定結果を見てください。
--     Int の全域から選ぶ   -> 重複はごくわずか
--     arbitrary (既定)     -> サイズが小さいので、それなりに重複する
--     choose (0,5)         -> ほぼ必ず重複する
--
--   自作の ID 型などで choose (minBound, maxBound) や UUID 風の生成をすると、
--   「衝突時の挙動」が一度も試されません。
--   テスト用には、わざと狭い範囲の生成器を用意してください。
