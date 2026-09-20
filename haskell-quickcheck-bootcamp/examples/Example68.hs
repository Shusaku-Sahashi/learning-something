-- Example 68: 前提条件が複数あるとき
--
-- 条件が増えると、通る確率は掛け算で下がります。
-- 2つ目、3つ目の条件を足した瞬間にテストが成立しなくなる、というのはよくある事故です。
--
-- 実行: runghc Example68.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 条件を1つずつ足していって、通過率がどう落ちるか測る
------------------------------------------------------------
measure :: String -> (Int -> Int -> Int -> Bool) -> IO ()
measure label cond = do
  triples <- sequence (replicate 5000 (generate gen3))
  let hits = length [ () | (a, b, c) <- triples, cond a b c ]
  putStrLn ("  " ++ pad 34 label ++ show hits ++ " / 5000")
  where
    gen3 = (,,) <$> arbitrary <*> arbitrary <*> arbitrary
    pad n s = s ++ replicate (n - length s) ' '

------------------------------------------------------------
-- 悪い例: 条件を重ねる
------------------------------------------------------------
prop_threeConditions :: Int -> Int -> Int -> Property
prop_threeConditions a b c =
  a > 0 && b > 0 && c > 0 && a < b && b < c
    ==> a < c

------------------------------------------------------------
-- 良い例1: Modifier で置き換えられる部分を置き換える
------------------------------------------------------------
prop_withModifiers :: Positive Int -> Positive Int -> Positive Int -> Property
prop_withModifiers (Positive a) (Positive b) (Positive c) =
  a < b && b < c ==> a < c

------------------------------------------------------------
-- 良い例2: 依存関係のある値を順に生成する
------------------------------------------------------------
genAscendingTriple :: Gen (Int, Int, Int)
genAscendingTriple = do
  a <- choose (1, 1000)
  b <- choose (a + 1, a + 1000)
  c <- choose (b + 1, b + 1000)
  pure (a, b, c)

prop_generated :: Property
prop_generated = forAll genAscendingTriple (\(a, _, c) -> a < c)

------------------------------------------------------------
-- 良い例3: 生成してから並べ替える (条件が「順序」なら最速)
------------------------------------------------------------
genSortedTriple :: Gen (Int, Int, Int)
genSortedTriple = do
  xs <- vectorOf 3 (choose (1, 1000))
  case sortTriple xs of
    [a, b, c] -> pure (a, b, c)
    _         -> pure (1, 2, 3)     -- ここには来ない
  where
    sortTriple = foldr ins []
    ins x []       = [x]
    ins x (y : ys) | x <= y    = x : y : ys
                   | otherwise = y : ins x ys

-- ただし「重複を許さない」なら、並べ替えただけでは足りません。
prop_sortedTripleStrict :: Property
prop_sortedTripleStrict =
  forAll genSortedTriple $ \(a, b, c) ->
    a <= b && b <= c

main :: IO ()
main = do
  putStrLn "--- how many random triples satisfy each condition? ---"
  measure "a > 0"                        (\a _ _ -> a > 0)
  measure "a > 0 && b > 0"               (\a b _ -> a > 0 && b > 0)
  measure "a > 0 && b > 0 && c > 0"      (\a b c -> a > 0 && b > 0 && c > 0)
  measure "... && a < b"                 (\a b c -> a > 0 && b > 0 && c > 0 && a < b)
  measure "... && a < b && b < c"        (\a b c -> a > 0 && b > 0 && c > 0 && a < b && b < c)
  putStrLn ""

  putStrLn "--- all conditions as preconditions ---"
  quickCheck prop_threeConditions
  putStrLn ""

  putStrLn "--- positivity via modifiers, ordering still a precondition ---"
  quickCheck prop_withModifiers
  putStrLn ""

  putStrLn "--- generated directly: no discards ---"
  quickCheck prop_generated
  putStrLn ""

  putStrLn "--- generated then sorted ---"
  quickCheck prop_sortedTripleStrict
  putStrLn ""

  putStrLn "--- samples from the ascending generator ---"
  ts <- sample' genAscendingTriple
  print (take 5 ts)

-- 数字で見ると衝撃的です。
--   条件1つ    : だいたい半分が通る
--   条件3つ    : 1/8 くらい
--   順序も足すと: 数パーセント
--
-- 条件が5つある仕様は珍しくありません。
-- そのまま (==>) で書くと、ほぼ確実に Gave up します。
--
-- 対処の型:
--   「正の数」     -> Positive
--   「空でない」   -> NonEmptyList
--   「昇順」       -> OrderedList、または生成してから sort
--   「a < b」      -> b を a に依存させて生成する (do 記法)
--   「重複なし」   -> nub してから使う
--   「合計が N」   -> N を先に決めて、分割を生成する
--
-- 最後の「合計が N」のような条件は特に厄介です。
-- 「条件から逆算して生成する」発想に切り替えてください。
