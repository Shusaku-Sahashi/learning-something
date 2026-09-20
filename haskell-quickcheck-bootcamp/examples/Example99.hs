-- Example 99: プロパティを育てる (変異テストで自己検証する)
--
-- 「自分のプロパティは、本当にバグを捕まえられるのか?」
-- これを機械的に確かめる方法が変異テスト (mutation testing) です。
--
-- 考え方: テスト対象をわざと壊した版 (ミュータント) をいくつも用意し、
--         「プロパティがそれを全部殺せるか」を見ます。
--         殺せないミュータントがあれば、プロパティが足りていません。
--
-- 実行: runghc Example99.hs
{-# LANGUAGE ExistentialQuantification #-}
module Main (main) where

import Data.List (sort)
import Test.QuickCheck

------------------------------------------------------------
-- 題材: 挿入ソート
------------------------------------------------------------
type SortFn = [Int] -> [Int]

-- 正しい実装
insertionSort :: SortFn
insertionSort = foldr ins []
  where
    ins x []       = [x]
    ins x (y : ys) | x <= y    = x : y : ys
                   | otherwise = y : ins x ys

------------------------------------------------------------
-- ミュータント (わざと壊した実装たち)
------------------------------------------------------------
mutants :: [(String, SortFn)]
mutants =
  [ ("M1 always []",        \_ -> [])
  , ("M2 identity",         id)
  , ("M3 reverse order",    \xs -> reverse (sort xs))
  , ("M4 drops duplicates", \xs -> dedup (sort xs))
  , ("M5 drops last",       \xs -> take (max 0 (length xs - 1)) (sort xs))
  , ("M6 appends a zero",   \xs -> sort xs ++ [0])
  , ("M7 wrong comparison", foldr insWrong [])
  , ("M8 sorts by abs",     sortByAbs)
  ]
  where
    dedup = foldr (\x acc -> case acc of
                               (y : _) | x == y -> acc
                               _                -> x : acc) []
    insWrong x []       = [x]
    insWrong x (y : ys) | x < y     = x : y : ys      -- <= ではなく <
                        | otherwise = y : insWrong x ys
    sortByAbs xs = map snd (sort [ (abs x, x) | x <- xs ])

------------------------------------------------------------
-- プロパティたち (段階的に足していく)
------------------------------------------------------------
data NamedProp = forall p. Testable p => NamedProp String (SortFn -> p)

propsV1 :: [NamedProp]
propsV1 =
  [ NamedProp "ordered" (\f xs -> isOrdered (f xs))
  ]

propsV2 :: [NamedProp]
propsV2 = propsV1 ++
  [ NamedProp "length preserved" (\f xs -> length (f xs) === length xs)
  ]

propsV3 :: [NamedProp]
propsV3 = propsV2 ++
  [ NamedProp "same elements" (\f xs -> sameMultiset (f xs) xs)
  ]

propsV4 :: [NamedProp]
propsV4 = propsV3 ++
  [ NamedProp "idempotent"    (\f xs -> f (f xs) === f xs)
  , NamedProp "head is min"   (\f xs -> not (null xs) ==> head (f xs) === minimum xs)
  ]

isOrdered :: [Int] -> Bool
isOrdered ys = and (zipWith (<=) ys (drop 1 ys))

sameMultiset :: [Int] -> [Int] -> Bool
sameMultiset a b = all (\x -> count x a == count x b) (a ++ b)
  where count x = length . filter (== x)

------------------------------------------------------------
-- 変異テストの実行
------------------------------------------------------------
-- 各ミュータントに対して、プロパティ群を走らせる。
-- 1つでも落ちれば「殺した (killed)」。全部通れば「生き残った (survived)」。
killed :: [NamedProp] -> SortFn -> IO Bool
killed props f = do
  results <- mapM (\(NamedProp _ p) -> do
                     r <- quickCheckWithResult
                            stdArgs { chatty = False, maxSuccess = 500 } (p f)
                     pure (isSuccess r))
                  props
  pure (not (and results))

runMutationTest :: String -> [NamedProp] -> IO ()
runMutationTest label props = do
  putStrLn ("--- " ++ label ++ " (" ++ show (length props) ++ " properties) ---")
  -- まず正しい実装が通ることを確認する (偽陽性がないこと)
  okOriginal <- killed props insertionSort
  putStrLn ("  original implementation: "
              ++ (if okOriginal then "FAILS (the properties are wrong!)" else "passes"))
  outcomes <- mapM (\(name, f) -> do
                      k <- killed props f
                      putStrLn ("  " ++ pad 22 name
                                  ++ (if k then "killed" else "SURVIVED"))
                      pure k)
                   mutants
  let n = length mutants
      k = length (filter id outcomes)
  putStrLn ("  score: " ++ show k ++ " / " ++ show n
              ++ "  (" ++ show (100 * k `div` n) ++ "%)")
  putStrLn ""
  where pad w s = s ++ replicate (w - length s) ' '

------------------------------------------------------------
-- 等価ミュータント: M7 はどうやっても殺せない
------------------------------------------------------------
-- M7 は比較を <= から < に変えたものです。
-- 等しい要素が来たとき、右に送るか左に置くかが変わります。
-- しかし要素が Int だと、等しい値は区別できません。
-- そのため出力はまったく同じになり、どんなプロパティでも殺せません。
-- これを「等価ミュータント (equivalent mutant)」と呼びます。
prop_m7IsEquivalent :: [Int] -> Property
prop_m7IsEquivalent xs = insertionSort xs === snd (mutants !! 6) xs

------------------------------------------------------------
-- 区別できる場面: 安定性 (stability)
------------------------------------------------------------
-- キーと「元の位置」のペアをキーだけで並べると、違いが見えます。
-- 安定ソートなら、キーが同じ要素の相対順序が保たれます。
type Tagged = (Int, Int)   -- (キー, 元の位置)

insStable :: Tagged -> [Tagged] -> [Tagged]
insStable x []       = [x]
insStable x (y : ys) | fst x <= fst y = x : y : ys
                     | otherwise      = y : insStable x ys

insUnstable :: Tagged -> [Tagged] -> [Tagged]
insUnstable x []       = [x]
insUnstable x (y : ys) | fst x < fst y = x : y : ys
                       | otherwise     = y : insUnstable x ys

tagged :: [Int] -> [Tagged]
tagged ks = zip ks [0 ..]

-- 安定性: キーが同じなら、元の位置の順序が保たれる
stable :: [Tagged] -> Bool
stable ys = and [ p1 < p2 | ((k1, p1), (k2, p2)) <- zip ys (drop 1 ys), k1 == k2 ]

prop_stableIsStable :: [Int] -> Property
prop_stableIsStable ks =
  counterexample (show (foldr insStable [] (tagged ks)))
    (property (stable (foldr insStable [] (tagged ks))))

prop_unstableIsNotStable :: Property
prop_unstableIsNotStable =
  expectFailure $
    forAll (listOf (choose (0, 2))) $ \ks ->
      counterexample (show (foldr insUnstable [] (tagged ks)))
        (stable (foldr insUnstable [] (tagged ks)))

main :: IO ()
main = do
  runMutationTest "V1: only 'ordered'"                     propsV1
  runMutationTest "V2: + length preserved"                 propsV2
  runMutationTest "V3: + same elements"                    propsV3
  runMutationTest "V4: + idempotent, head is min"          propsV4

  putStrLn "--- what this tells us ---"
  putStrLn "  V1 kills only half: 'ordered' alone is a very weak spec."
  putStrLn "    ('always []' and 'drops duplicates' both produce ordered output)"
  putStrLn "  V2 kills everything that changes the length."
  putStrLn "  V3 adds nothing here, but it is what makes the spec COMPLETE:"
  putStrLn "    ordered + same multiset  =>  it IS the sorted list."
  putStrLn "  V4 adds nothing in terms of killing. The properties are still"
  putStrLn "  useful as documentation and as faster-failing checks."
  putStrLn ""

  putStrLn "--- M7 survives everything. Why? ---"
  putStr "  M7 is behaviourally identical : "
  quickCheckWith stdArgs { maxSuccess = 5000 } prop_m7IsEquivalent
  putStrLn "  ^ an EQUIVALENT MUTANT: no property on [Int] can ever kill it."
  putStrLn ""

  putStrLn "--- but the difference IS observable on tagged elements ---"
  let ks = [1, 0, 1, 0] :: [Int]
  putStrLn ("  input (key, position): " ++ show (tagged ks))
  putStrLn ("  with <= (stable)     : " ++ show (foldr insStable [] (tagged ks)))
  putStrLn ("  with <  (unstable)   : " ++ show (foldr insUnstable [] (tagged ks)))
  putStr "  stable version is stable   : " >> quickCheck prop_stableIsStable
  putStr "  unstable version is not    : " >> quickCheck prop_unstableIsNotStable

-- 変異テストの使い方:
--
--   1. テスト対象の「ありそうな壊し方」を5〜10個書く
--        * 境界をずらす (< を <=, n を n-1)
--        * 分岐を反転する
--        * 恒等関数にする / 定数を返す
--        * 要素を1つ落とす / 足す
--        * 順序を逆にする
--
--   2. 全部殺せるまでプロパティを足す
--
--   3. 殺せないミュータントが残ったら、次のどちらかです。
--      (a) 仕様の穴: プロパティが足りない -> 足す
--      (b) 等価ミュータント: 振る舞いが同じなので、そもそも殺せない
--
--      (b) の見分け方は「元の実装と出力が常に一致するか」を
--      プロパティで確かめることです (上の prop_m7IsEquivalent)。
--
--      ただし (b) だと分かっても、それで終わりにしないでください。
--      上の M7 は [Int] では区別できませんが、
--      「キー付きの要素をキーだけで並べる」場面では安定性の差として現れます。
--      「今の型では区別できないが、使い方次第では意味がある差」なのです。
--
-- ★ 「完全な仕様」に到達したかの見分け方
--
--   ソートの場合、
--     「順序が正しい」かつ「元と同じ多重集合」
--   を両方満たす実装は、ソートしかありえません。
--   つまり V3 で仕様は完全です。
--
--   自分の関数についても「この性質を全部満たす、間違った実装を書けるか?」
--   と自問してください。書けなくなったら、そこがゴールです。
--
-- ★ 手動でやる価値
--
--   Haskell には自動の変異テストツール (MuCheck など) もありますが、
--   手で 5 個ミュータントを書くだけでも十分に効果があります。
--   テストを書いた直後に 10 分だけやってみてください。
