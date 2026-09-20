-- Example 27: 条件を満たす値だけを作る (suchThat)
--
-- 「偶数だけ」「空でないリストだけ」のように、条件付きの値が欲しいときの道具。
-- ただし使い方を誤ると簡単に固まるので、注意点まで含めて覚えてください。
--
-- 実行: runghc Example27.hs
module Main (main) where

import Test.QuickCheck

-- suchThat :: Gen a -> (a -> Bool) -> Gen a
--   条件を満たすまで生成し直す。
genEven :: Gen Int
genEven = arbitrary `suchThat` even

genNonEmpty :: Gen [Int]
genNonEmpty = arbitrary `suchThat` (not . null)

genPositive :: Gen Int
genPositive = arbitrary `suchThat` (> 0)

-- ★ 危険な例: 条件が厳しすぎると、いつまでも生成できません。
--   下の生成器は「1000000 より大きい Int」を要求しますが、
--   QuickCheck の Int はサイズに比例した小さい値を作るため、
--   ほとんど当たりません。サイズが上がるまで延々とやり直します。
--
--     genHuge = arbitrary `suchThat` (> 1000000)   -- とても遅い
--
--   正しくは、条件で弾くのではなく「最初からその範囲を作る」ことです。
genHugeGood :: Gen Int
genHugeGood = choose (1000001, maxBound)

-- 同様に、偶数も「弾く」より「作る」ほうが速く確実です。
genEvenGood :: Gen Int
genEvenGood = (* 2) <$> arbitrary

-- suchThatMaybe :: Gen a -> (a -> Bool) -> Gen (Maybe a)
--   有限回だけ試して、ダメなら Nothing。固まりません。
genMaybeBig :: Gen (Maybe Int)
genMaybeBig = arbitrary `suchThatMaybe` (> 1000000)

-- suchThatMap :: Gen a -> (a -> Maybe b) -> Gen b
--   生成しつつ変換し、Nothing なら作り直す。
--   「生成して、変換に成功したものだけ使う」ときに便利です。
genDigitChar :: Gen Char
genDigitChar = arbitrary `suchThatMap` keepDigit
  where keepDigit c = if c `elem` ['0' .. '9'] then Just c else Nothing

main :: IO ()
main = do
  putStrLn "--- suchThat even ---"
  a <- sample' genEven
  print a

  putStrLn "--- suchThat (not . null) ---"
  b <- sample' genNonEmpty
  print (map length b)

  putStrLn "--- suchThat (> 0) ---"
  c <- sample' genPositive
  print c

  putStrLn "--- better: build it directly ---"
  d <- sample' genEvenGood
  print d
  e <- sample' genHugeGood
  print (map (> 1000000) e)

  putStrLn "--- suchThatMaybe (may give Nothing, never hangs) ---"
  f <- sample' genMaybeBig
  print f

  putStrLn "--- suchThatMap: only digit characters ---"
  g <- sample' genDigitChar
  print g

  putStrLn ""
  putStrLn "--- properties ---"
  quickCheck (forAll genEven even)
  quickCheck (forAll genEvenGood even)
  quickCheck (forAll genNonEmpty (not . null))
  quickCheck (forAll genDigitChar (`elem` ['0' .. '9']))

-- 原則:
--   「弾く」より「作る」。
--   suchThat は「ほとんどの値が条件を満たす」ときだけ使ってください。
--   目安として、条件を満たす確率が 1/10 を切るなら、生成器を書き直すべきです。
--
--   条件を満たす確率が低いと何が起きるか:
--     * テストが極端に遅くなる
--     * 生成される値が偏る (「たまたま条件を満たした変な値」ばかりになる)
--     * サイズが小さいうちは生成できず、実質的に小さい入力が試されない
--
-- なお、プロパティ側で条件を絞る (==>) も同じ問題を抱えています。Ch6 で扱います。
