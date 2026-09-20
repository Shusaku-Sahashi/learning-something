-- Example 41: 関数を生成する (Fun と applyFun)
--
-- 「どんな関数 f に対しても成り立つ」性質を書きたいことがあります。
--   map f . map g == map (f . g)
--   fmap id == id
-- しかし Haskell の関数は Show できないので、そのままでは反例を表示できません。
-- QuickCheck は Fun という仕組みでこれを解決します。
--
-- 実行: runghc Example41.hs
module Main (main) where

import Test.QuickCheck

-- Fun a b は「表示できる関数」です。
--   パターン Fn f で関数を取り出します (applyFun でも同じ)。
--   Show インスタンスがあり、反例として出るときには
--   「どの入力で何を返すか」の表が表示されます。
--
--   注意: 生成しただけの Fun を print すると <fun> としか出ません。
--   表が見えるのは「縮小されたあと」、つまり反例として表示されるときだけです。
--   これは、表がテスト中に実際に問い合わせられた入力から作られるためです。

-- map の融合則。任意の関数2つで成り立つはず。
prop_mapFusion :: Fun Int Int -> Fun Int Int -> [Int] -> Property
prop_mapFusion (Fn f) (Fn g) xs =
  map f (map g xs) === map (f . g) xs

-- applyFun を使う書き方 (Fn パターンと同じ意味)
prop_mapFusion2 :: Fun Int Int -> Fun Int Int -> [Int] -> Property
prop_mapFusion2 f g xs =
  map (applyFun f) (map (applyFun g) xs) === map (applyFun f . applyFun g) xs

-- filter は「述語を満たすものだけ残す」
prop_filterAll :: Fun Int Bool -> [Int] -> Bool
prop_filterAll (Fn p) xs = all p (filter p xs)

prop_filterLength :: Fun Int Bool -> [Int] -> Bool
prop_filterLength (Fn p) xs = length (filter p xs) <= length xs

-- filter を2回かけるのは、条件を and でつなぐのと同じ
prop_filterFusion :: Fun Int Bool -> Fun Int Bool -> [Int] -> Property
prop_filterFusion (Fn p) (Fn q) xs =
  filter p (filter q xs) === filter (\x -> q x && p x) xs

-- 2引数関数は Fun (a, b) c を使います
prop_uncurry :: Fun (Int, Int) Int -> Int -> Int -> Property
prop_uncurry (Fn f) x y = f (x, y) === curry f x y

-- ★ わざと成り立たない性質: 「map f は長さを変えない」は真だが、
--   「filter p は長さを変えない」は偽。反例に「どんな p だったか」が出ます。
prop_filterKeepsLength :: Fun Int Bool -> [Int] -> Property
prop_filterKeepsLength (Fn p) xs = length (filter p xs) === length xs

main :: IO ()
main = do
  putStrLn "--- a freshly generated Fun prints as <fun> ---"
  fs <- sample' (arbitrary :: Gen (Fun Int Int))
  mapM_ print (take 3 fs)
  putStrLn "  (the table shows up only in counterexamples, see the bottom)"
  putStrLn ""

  putStrLn "--- properties over arbitrary functions ---"
  putStr "map fusion (Fn)      : " >> quickCheck prop_mapFusion
  putStr "map fusion (applyFun): " >> quickCheck prop_mapFusion2
  putStr "filter all           : " >> quickCheck prop_filterAll
  putStr "filter length <=     : " >> quickCheck prop_filterLength
  putStr "filter fusion        : " >> quickCheck prop_filterFusion
  putStr "curry / uncurry      : " >> quickCheck prop_uncurry
  putStrLn ""
  putStrLn "--- a false property: the counterexample shows the function ---"
  quickCheck prop_filterKeepsLength

-- 最後の反例を見てください。
--
--   {_->False}
--   [0]
--   0 /= 1
--
-- {_->False} は「どんな入力でも False を返す関数」という意味です。
-- 入力 [0] に対して filter は [] を返すので長さ 0、元のリストは長さ 1。
-- だから 0 /= 1 で失敗しました。
--
-- 入力ごとに値が違う関数なら、こういう表示になります:
--
--   {0 -> True, _ -> False}
--
-- QuickCheck は、テスト中に実際に問い合わせられた入力だけを記録して、
-- 最小限の表に縮小して見せてくれます。
--
-- 使い分け:
--   Fn f        パターンマッチで関数を取り出す (読みやすい)
--   applyFun f  関数として適用する (点なしスタイルで書きたいとき)
--   Fn2, Fn3    2引数、3引数のパターン (Fun (a,b) c のショートカット)
--
-- 注意:
--   Fun a b が使えるのは、a に CoArbitrary と Function のインスタンスが
--   あるときだけです。標準的な型にはたいてい付いています。
--   自作の型で使いたい場合は Example 42 を見てください。
