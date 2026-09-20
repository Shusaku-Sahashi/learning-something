-- Example 53: shrink が終わらない問題
--
-- shrink の契約「返す値は元より厳密に小さい」を破ると、縮小が止まりません。
-- QuickCheck はハングします。原因が分かりにくいので、パターンを覚えてください。
--
-- 実行: runghc Example53.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 失敗パターン1: 自分自身を候補に含める
------------------------------------------------------------
newtype Loop1 = Loop1 Int
  deriving (Show, Eq)

instance Arbitrary Loop1 where
  arbitrary = Loop1 <$> choose (0, 100)
  -- ★ 自分自身が候補に入っている -> 永遠に縮小し続ける
  shrink (Loop1 n) = [ Loop1 n ] ++ [ Loop1 n' | n' <- shrink n ]

------------------------------------------------------------
-- 失敗パターン2: スマートコンストラクタが値を変えない
------------------------------------------------------------
-- 「5 未満なら 5 に切り上げる」正規化を考えます。
-- 値が 5 のとき、縮小候補 (0, 3, 4 など) はすべて 5 に切り上げられ、
-- 結果として「自分自身」が候補に並びます。
newtype Loop2 = Loop2 Int
  deriving (Show, Eq)

atLeast5 :: Int -> Int
atLeast5 = max 5

instance Arbitrary Loop2 where
  arbitrary = Loop2 . atLeast5 <$> arbitrary
  -- ★ 正規化を通すと、元の値に戻る候補が生まれる
  shrink (Loop2 n) = [ Loop2 (atLeast5 n') | n' <- shrink n ]

------------------------------------------------------------
-- 失敗パターン3: 「大きさ」の定義を間違える
------------------------------------------------------------
-- 「リストを逆順にする」のは縮小ではありません。同じ大きさのまま往復します。
newtype Loop3 = Loop3 [Int]
  deriving (Show, Eq)

instance Arbitrary Loop3 where
  arbitrary = Loop3 <$> arbitrary
  -- ★ reverse は大きさを変えない。[1,2] -> [2,1] -> [1,2] -> ...
  shrink (Loop3 xs) = [ Loop3 (reverse xs) | length xs > 1 ]

------------------------------------------------------------
-- 検出のしかた: 「自分自身が候補にいないか」を確かめるプロパティ
------------------------------------------------------------
-- ★ 重要な注意
--   壊れた shrink を quickCheck でそのままテストすると、
--   「反例が見つかる -> その反例を shrink で縮小しようとする -> 無限ループ」
--   となって固まります。テスト対象の shrink が、反例の縮小にも使われるためです。
--
--   そこで forAll を使い、生成だけ行って縮小はしない形にします
--   (forAll は縮小しません。Example 44 を参照)。
--   quickCheckWith stdArgs { maxShrinks = 0 } でも回避できます。

prop_loop1NoSelf :: Property
prop_loop1NoSelf = forAll (arbitrary :: Gen Loop1) $ \x ->
  counterexample (show (take 3 (shrink x))) (x `notElem` shrink x)

prop_loop2NoSelf :: Property
prop_loop2NoSelf = forAll (arbitrary :: Gen Loop2) $ \x ->
  counterexample (show (take 3 (shrink x))) (x `notElem` shrink x)

prop_loop3NoSelf :: Property
prop_loop3NoSelf = forAll (arbitrary :: Gen Loop3) $ \x ->
  counterexample (show (take 3 (shrink x))) (x `notElem` shrink x)

-- もっと強い検査: 「先頭の候補をたどり続けて、同じ値に戻らないか」
-- QuickCheck の縮小は貪欲法なので、失敗し続ける限り先頭の候補を採り続けます。
-- その経路をたどって、既に見た値に戻ったらループ確定です。
noCycleIn :: (Eq a) => Int -> (a -> [a]) -> a -> Bool
noCycleIn depth shr x0 = go depth [x0] x0
  where
    go 0 _    _ = True
    go k seen x = case shr x of
      []      -> True
      (y : _) -> y `notElem` seen && go (k - 1) (y : seen) y

prop_loop3NoCycle :: Property
prop_loop3NoCycle = forAll (arbitrary :: Gen [Int]) $ \xs ->
  counterexample (show xs)
    (noCycleIn 20 (\ys -> [ reverse ys | length ys > 1 ]) xs)

-- 正しい shrink なら、この検査は通ります。
prop_fine3NoCycle :: Property
prop_fine3NoCycle = forAll (arbitrary :: Gen [Int]) $ \xs ->
  noCycleIn 20 shrink xs

------------------------------------------------------------
-- 正しい書き方
------------------------------------------------------------
newtype Fine1 = Fine1 Int
  deriving (Show, Eq)

instance Arbitrary Fine1 where
  arbitrary = Fine1 <$> choose (0, 100)
  shrink (Fine1 n) = [ Fine1 n' | n' <- shrink n ]      -- 自分自身は含まれない

newtype Fine2 = Fine2 Int
  deriving (Show, Eq)

instance Arbitrary Fine2 where
  arbitrary = Fine2 . atLeast5 <$> arbitrary
  -- ★ 修正: 正規化した結果が元と同じものを除く
  shrink (Fine2 n) = [ Fine2 m | n' <- shrink n, let m = atLeast5 n', m /= n ]

newtype Fine3 = Fine3 [Int]
  deriving (Show, Eq)

instance Arbitrary Fine3 where
  arbitrary = Fine3 <$> arbitrary
  -- ★ 修正: 本当に小さくなる操作 (要素を削る) にする
  shrink (Fine3 xs) = [ Fine3 ys | ys <- shrink xs ]

prop_fine1NoSelf :: Fine1 -> Bool
prop_fine1NoSelf x = x `notElem` shrink x

prop_fine2NoSelf :: Fine2 -> Bool
prop_fine2NoSelf x = x `notElem` shrink x

prop_fine3NoSelf :: Fine3 -> Bool
prop_fine3NoSelf x = x `notElem` shrink x

main :: IO ()
main = do
  putStrLn "--- broken shrinks, detected automatically ---"
  putStrLn "Loop1 (includes itself):"
  quickCheck prop_loop1NoSelf
  putStrLn "Loop2 (normalisation maps a value to itself):"
  quickCheck prop_loop2NoSelf
  putStrLn "Loop3 (reverse is not smaller):"
  quickCheck prop_loop3NoSelf
  putStrLn "Loop3, cycle detection (the self-check above was not enough):"
  quickCheck prop_loop3NoCycle
  putStrLn "Fine3, cycle detection (a correct shrink passes):"
  quickCheck prop_fine3NoCycle
  putStrLn ""

  putStrLn "--- what the broken shrinks return ---"
  putStrLn ("  shrink (Loop1 4)      = " ++ show (take 4 (shrink (Loop1 4))))
  putStrLn ("  shrink (Loop2 5)      = " ++ show (take 4 (shrink (Loop2 5))))
  putStrLn ("  shrink (Loop2 9)      = " ++ show (take 4 (shrink (Loop2 9))))
  putStrLn ("  shrink (Loop3 [1,2])  = " ++ show (shrink (Loop3 [1, 2])))
  putStrLn ""

  putStrLn "--- fixed versions ---"
  putStrLn ("  shrink (Fine1 4)      = " ++ show (shrink (Fine1 4)))
  putStrLn ("  shrink (Fine2 5)      = " ++ show (shrink (Fine2 5)))
  putStrLn ("  shrink (Fine2 9)      = " ++ show (shrink (Fine2 9)))
  putStrLn ("  shrink (Fine3 [1,2])  = " ++ show (shrink (Fine3 [1, 2])))
  putStr "Fine1 : " >> quickCheck prop_fine1NoSelf
  putStr "Fine2 : " >> quickCheck prop_fine2NoSelf
  putStr "Fine3 : " >> quickCheck prop_fine3NoSelf
  putStrLn ""

  putStrLn "--- safety net: maxShrinks ---"
  putStrLn "  If you suspect a shrink loop, cap the number of shrinks:"
  quickCheckWith stdArgs { maxShrinks = 10 } (\xs -> length (xs :: [Int]) < 3)

-- まとめ:
--
--   必ず書くべきプロパティ:
--     prop_shrinkIsSmaller :: MyType -> Bool
--     prop_shrinkIsSmaller x = x `notElem` shrink x
--
--   これ1本で、上の3パターンすべてを検出できます。
--
--   ハングしたときの応急処置:
--     quickCheckWith stdArgs { maxShrinks = 100 } prop
--   縮小を打ち切れるので、少なくとも反例は表示されます。
--
--   そして、壊れた shrink のテスト自体は forAll で書いてください。
--   そうしないと、テストのほうが先に固まります。
--
--   ただし「自分自身を含まない」だけでは足りない場合があります。
--   Loop3 がその例で、a -> b -> a という長さ 2 の循環は
--   「自分自身が直接の候補にいるか」では検出できません。
--   実際、上の実行結果では Loop3 の自己チェックは通ってしまい、
--   noCycleIn による経路の追跡でようやく検出されています。
--
--   まとめると:
--     まず  x `notElem` shrink x  を書く (ほとんどのバグはこれで出る)
--     再帰型や正規化つきの型では noCycleIn のような経路チェックも足す
