-- Example 22: ケーススタディ「プロパティを仕様書として使う」
--
-- 実装より先にプロパティを書きます (property-first)。
-- プロパティが仕様書になり、そのまま回帰テストになります。
--
-- お題: chunksOf n xs
--   リスト xs を長さ n のかたまりに分割する。
--   例: chunksOf 3 [1..7] == [[1,2,3],[4,5,6],[7]]
--
-- 実行: runghc Example22.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- STEP 1: 仕様をプロパティとして書き下す (実装はまだない)
------------------------------------------------------------
-- 仕様1: 全部つなげると元に戻る          -> これが本質
-- 仕様2: 最後以外のかたまりは長さ n ちょうど
-- 仕様3: 最後のかたまりは 1 以上 n 以下
-- 仕様4: 空リストなら空の結果
-- 仕様5: かたまりの個数は ceiling(length xs / n)

------------------------------------------------------------
-- STEP 2: 実装する
------------------------------------------------------------
chunksOf :: Int -> [a] -> [[a]]
chunksOf n xs
  | n <= 0    = []          -- n が 0 以下のときは空を返す約束にする
  | null xs   = []
  | otherwise = take n xs : chunksOf n (drop n xs)

------------------------------------------------------------
-- STEP 3: プロパティをコードにする
------------------------------------------------------------
-- n は正の数だけを使いたいので Positive Modifier を使います (Ch6 で詳しく)。
prop_concatRoundTrip :: Positive Int -> [Int] -> Property
prop_concatRoundTrip (Positive n) xs = concat (chunksOf n xs) === xs

prop_allButLastFull :: Positive Int -> [Int] -> Property
prop_allButLastFull (Positive n) xs =
  let cs = chunksOf n xs
  in conjoin [ length c === n | c <- dropLast cs ]
  where dropLast ys = take (max 0 (length ys - 1)) ys

prop_lastChunkSize :: Positive Int -> [Int] -> Property
prop_lastChunkSize (Positive n) xs =
  not (null xs) ==>
    let cs = chunksOf n xs
        l  = length (last cs)
    in counterexample ("last chunk length = " ++ show l) (l >= 1 && l <= n)

prop_emptyInput :: Positive Int -> Property
prop_emptyInput (Positive n) = chunksOf n ([] :: [Int]) === []

prop_chunkCount :: Positive Int -> [Int] -> Property
prop_chunkCount (Positive n) xs =
  length (chunksOf n xs) === ceilDiv (length xs) n
  where ceilDiv a b = (a + b - 1) `div` b

prop_noEmptyChunks :: Positive Int -> [Int] -> Bool
prop_noEmptyChunks (Positive n) xs = all (not . null) (chunksOf n xs)

-- 境界: n が 0 以下のときの約束も書いておく
prop_nonPositiveN :: [Int] -> Property
prop_nonPositiveN xs =
  conjoin [ chunksOf 0 xs === [], chunksOf (-1) xs === [] ]

-- n = 1 なら 1要素ずつのリストになる
prop_nIsOne :: [Int] -> Property
prop_nIsOne xs = chunksOf 1 xs === map (: []) xs

-- n が長さ以上なら 1個のかたまり
prop_nTooBig :: [Int] -> Property
prop_nTooBig xs =
  not (null xs) ==> chunksOf (length xs + 1) xs === [xs]

------------------------------------------------------------
-- STEP 4: わざと壊した実装で、プロパティが検出できるか確認する
--         (プロパティ自身のテスト。これを忘れると「何も検出しないテスト」が残ります)
------------------------------------------------------------
chunksOfBuggy :: Int -> [a] -> [[a]]
chunksOfBuggy n xs
  | n <= 0    = []
  | null xs   = []
  | otherwise = take n xs : chunksOfBuggy n (drop (n + 1) xs)  -- ★ off-by-one: 1要素多く捨てている

prop_buggyRoundTrip :: Positive Int -> [Int] -> Property
prop_buggyRoundTrip (Positive n) xs = concat (chunksOfBuggy n xs) === xs

main :: IO ()
main = do
  putStrLn "--- spec of chunksOf ---"
  putStr "concat round-trip  : " >> quickCheck prop_concatRoundTrip
  putStr "all but last full  : " >> quickCheck prop_allButLastFull
  putStr "last chunk size    : " >> quickCheck prop_lastChunkSize
  putStr "empty input        : " >> quickCheck prop_emptyInput
  putStr "chunk count        : " >> quickCheck prop_chunkCount
  putStr "no empty chunks    : " >> quickCheck prop_noEmptyChunks
  putStr "n <= 0             : " >> quickCheck prop_nonPositiveN
  putStr "n = 1              : " >> quickCheck prop_nIsOne
  putStr "n > length         : " >> quickCheck prop_nTooBig
  putStrLn ""
  putStrLn "--- same spec against a buggy implementation (must FAIL) ---"
  quickCheck prop_buggyRoundTrip
  putStrLn ("  chunksOf      3 [1..7] = " ++ show (chunksOf 3 [1 .. 7 :: Int]))
  putStrLn ("  chunksOfBuggy 3 [1..7] = " ++ show (chunksOfBuggy 3 [1 .. 7 :: Int]))

-- 補足: バグ版を書くときの注意
--   最初 drop (n - 1) と書いたところ、n = 1 のとき drop 0 になって
--   無限ループしました。バグ版といえども停止はする必要があります。
--   (もし本物のコードでこうなったら QuickCheck は固まります。
--    そういうときは within でタイムアウトを付けます。Example 84)
--
-- STEP 4 が一番大事です。
-- 「壊した実装を入れたらテストが落ちるか」を必ず確認してください。
-- 落ちないなら、そのプロパティは何も守っていません。
-- この作業は mutation testing (変異テスト) と呼ばれる考え方の手動版です。
--
-- Ch2 のまとめ: プロパティを探すときのチェックリスト
--   1. 往復するものはないか            (encode/decode, insert/lookup)
--   2. 変わらないものは何か            (長さ、要素の集合、順序)
--   3. 2回やったら同じか               (正規化、ソート、削除)
--   4. 代数法則を満たすか              (結合律、交換律、単位元)
--   5. 比べられる別実装はないか        (標準ライブラリ、素朴な実装、旧版)
--   6. 入力を変えたら出力はどう変わるか (単調性、分配則)
--   7. 構造に沿った性質はあるか        (++ や : に対する振る舞い)
--   8. とにかく落ちないか              (total)
