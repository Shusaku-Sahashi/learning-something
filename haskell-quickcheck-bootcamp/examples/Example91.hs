-- Example 91: データ構造を丸ごと検証する (二分探索木)
--
-- Ch2 から Ch8 までの技を全部使って、1つのデータ構造を仕上げます。
--
-- 実行: runghc Example91.hs
module Main (main) where

import Data.List (sort, nub)
import qualified Data.Set as S
import Test.QuickCheck

------------------------------------------------------------
-- 実装: 二分探索木 (平衡なし)
------------------------------------------------------------
data BST
  = Tip
  | Node BST Int BST
  deriving (Show, Eq)

emptyT :: BST
emptyT = Tip

insertT :: Int -> BST -> BST
insertT x Tip = Node Tip x Tip
insertT x t@(Node l v r)
  | x < v     = Node (insertT x l) v r
  | x > v     = Node l v (insertT x r)
  | otherwise = t                       -- 重複は入れない

memberT :: Int -> BST -> Bool
memberT _ Tip = False
memberT x (Node l v r)
  | x < v     = memberT x l
  | x > v     = memberT x r
  | otherwise = True

deleteT :: Int -> BST -> BST
deleteT _ Tip = Tip
deleteT x (Node l v r)
  | x < v     = Node (deleteT x l) v r
  | x > v     = Node l v (deleteT x r)
  | otherwise = merge l r
  where
    merge Tip t = t
    merge t Tip = t
    merge a b   = let m = minT b in Node a m (deleteT m b)
    minT (Node Tip v' _) = v'
    minT (Node l' _ _)   = minT l'
    minT Tip             = error "minT: empty"

toListT :: BST -> [Int]
toListT Tip          = []
toListT (Node l v r) = toListT l ++ [v] ++ toListT r

fromListT :: [Int] -> BST
fromListT = foldr insertT Tip

sizeT :: BST -> Int
sizeT Tip          = 0
sizeT (Node l _ r) = sizeT l + 1 + sizeT r

unionT :: BST -> BST -> BST
unionT a b = foldr insertT a (toListT b)

------------------------------------------------------------
-- 表現不変条件: 探索木の性質を満たしているか
------------------------------------------------------------
validBST :: BST -> Bool
validBST t = go t Nothing Nothing
  where
    go Tip _ _ = True
    go (Node l v r) lo hi =
      maybe True (< v) lo
        && maybe True (> v) hi
        && go l lo (Just v)
        && go r (Just v) hi

------------------------------------------------------------
-- 生成器と縮小
------------------------------------------------------------
instance Arbitrary BST where
  -- スマートコンストラクタ (insertT) を通すので、不変条件が自動的に保たれる
  arbitrary = fromListT <$> arbitrary
  -- 縮小も、リストに落としてから作り直す
  shrink t = [ fromListT xs | xs <- shrink (toListT t), fromListT xs /= t ]

-- 「空でない木」を狙い撃ちする生成器
genNonEmptyT :: Gen BST
genNonEmptyT = fromListT <$> listOf1 arbitrary

-- 「木と、その中に実在する要素」
genTreeAndMember :: Gen (BST, Int)
genTreeAndMember = do
  t <- genNonEmptyT
  x <- elements (toListT t)
  pure (t, x)

------------------------------------------------------------
-- (1) 生成器と縮小の検証 (Ch4, Ch5)
------------------------------------------------------------
prop_genValid :: BST -> Bool
prop_genValid = validBST

prop_shrinkValid :: BST -> Bool
prop_shrinkValid t = all validBST (shrink t)

prop_shrinkNoSelf :: BST -> Bool
prop_shrinkNoSelf t = t `notElem` shrink t

------------------------------------------------------------
-- (2) 不変条件が操作で保たれる (Ch2)
------------------------------------------------------------
prop_insertKeepsValid :: Int -> BST -> Bool
prop_insertKeepsValid x t = validBST (insertT x t)

prop_deleteKeepsValid :: Int -> BST -> Bool
prop_deleteKeepsValid x t = validBST (deleteT x t)

prop_unionKeepsValid :: BST -> BST -> Bool
prop_unionKeepsValid a b = validBST (unionT a b)

------------------------------------------------------------
-- (3) 往復・冪等性 (Ch2)
------------------------------------------------------------
prop_insertThenMember :: Int -> BST -> Bool
prop_insertThenMember x t = memberT x (insertT x t)

prop_deleteThenNotMember :: Int -> BST -> Bool
prop_deleteThenNotMember x t = not (memberT x (deleteT x t))

prop_insertIdempotent :: Int -> BST -> Property
prop_insertIdempotent x t = insertT x (insertT x t) === insertT x t

prop_deleteIdempotent :: Int -> BST -> Property
prop_deleteIdempotent x t = deleteT x (deleteT x t) === deleteT x t

------------------------------------------------------------
-- (4) 局所性 (Ch2)
------------------------------------------------------------
prop_insertOther :: Int -> Int -> BST -> Property
prop_insertOther x y t = x /= y ==> memberT y (insertT x t) === memberT y t

prop_deleteOther :: Int -> Int -> BST -> Property
prop_deleteOther x y t = x /= y ==> memberT y (deleteT x t) === memberT y t

------------------------------------------------------------
-- (5) モデル比較: Data.Set をオラクルにする (Ch8)
------------------------------------------------------------
abstract :: BST -> S.Set Int
abstract = S.fromList . toListT

prop_modelInsert :: Int -> BST -> Property
prop_modelInsert x t = abstract (insertT x t) === S.insert x (abstract t)

prop_modelDelete :: Int -> BST -> Property
prop_modelDelete x t = abstract (deleteT x t) === S.delete x (abstract t)

prop_modelMember :: Int -> BST -> Property
prop_modelMember x t = memberT x t === S.member x (abstract t)

prop_modelSize :: BST -> Property
prop_modelSize t = sizeT t === S.size (abstract t)

prop_modelUnion :: BST -> BST -> Property
prop_modelUnion a b = abstract (unionT a b) === S.union (abstract a) (abstract b)

------------------------------------------------------------
-- (6) toList は昇順で重複なし
------------------------------------------------------------
prop_toListSorted :: BST -> Property
prop_toListSorted t = let xs = toListT t in xs === sort (nub xs)

prop_fromToRoundTrip :: [Int] -> Property
prop_fromToRoundTrip xs = toListT (fromListT xs) === sort (nub xs)

------------------------------------------------------------
-- (7) 狙い撃ち生成器を使ったプロパティ (Ch4)
------------------------------------------------------------
prop_existingMemberFound :: Property
prop_existingMemberFound =
  forAll genTreeAndMember (\(t, x) -> memberT x t)

prop_deleteExistingReducesSize :: Property
prop_deleteExistingReducesSize =
  forAll genTreeAndMember (\(t, x) -> sizeT (deleteT x t) === sizeT t - 1)

------------------------------------------------------------
-- (8) 分布の確認 (Ch7)
------------------------------------------------------------
prop_coverage :: Property
prop_coverage =
  checkCoverage $
  forAll (arbitrary :: Gen BST) $ \t ->
    cover 5  (sizeT t == 0)  "empty"       $
    cover 30 (sizeT t >= 3)  "3 or more"   $
    cover 10 (sizeT t >= 10) "10 or more"  $
      validBST t

------------------------------------------------------------
-- (9) 全域性 (Ch2)
------------------------------------------------------------
prop_noCrashes :: Int -> BST -> Property
prop_noCrashes x t =
  total ( toListT (insertT x t)
        , toListT (deleteT x t)
        , memberT x t
        , sizeT t )

main :: IO ()
main = do
  putStrLn "--- sample trees (as sorted lists) ---"
  ts <- sample' (arbitrary :: Gen BST)
  mapM_ (print . toListT) (take 5 ts)
  putStrLn ""

  section "generator and shrink"
    [ ("generator valid   ", quickCheck prop_genValid)
    , ("shrink valid      ", quickCheck prop_shrinkValid)
    , ("shrink no self    ", quickCheck prop_shrinkNoSelf)
    ]

  section "invariant preserved"
    [ ("insert            ", quickCheck prop_insertKeepsValid)
    , ("delete            ", quickCheck prop_deleteKeepsValid)
    , ("union             ", quickCheck prop_unionKeepsValid)
    ]

  section "round trip / idempotence"
    [ ("insert then member", quickCheck prop_insertThenMember)
    , ("delete then absent", quickCheck prop_deleteThenNotMember)
    , ("insert idempotent ", quickCheck prop_insertIdempotent)
    , ("delete idempotent ", quickCheck prop_deleteIdempotent)
    ]

  section "locality"
    [ ("insert other key  ", quickCheck prop_insertOther)
    , ("delete other key  ", quickCheck prop_deleteOther)
    ]

  section "model (Data.Set)"
    [ ("insert            ", quickCheck prop_modelInsert)
    , ("delete            ", quickCheck prop_modelDelete)
    , ("member            ", quickCheck prop_modelMember)
    , ("size              ", quickCheck prop_modelSize)
    , ("union             ", quickCheck prop_modelUnion)
    ]

  section "ordering"
    [ ("toList sorted     ", quickCheck prop_toListSorted)
    , ("from/to round trip", quickCheck prop_fromToRoundTrip)
    ]

  section "targeted generators"
    [ ("existing member   ", quickCheck prop_existingMemberFound)
    , ("delete reduces    ", quickCheck prop_deleteExistingReducesSize)
    ]

  section "coverage and totality"
    [ ("size distribution ", quickCheck prop_coverage)
    , ("no crashes        ", quickCheck prop_noCrashes)
    ]
  where
    section title items = do
      putStrLn ("--- " ++ title ++ " ---")
      mapM_ (\(n, act) -> putStr (n ++ ": ") >> act) items
      putStrLn ""

-- このくらい書けば、データ構造の正しさはかなり固まります。
-- 数は多く見えますが、1本あたり1〜3行です。
--
-- 書く順番の推奨:
--   1. 生成器と縮小の検証      (これがないと以降が信用できない)
--   2. 表現不変条件            (壊れた木を作っていないか)
--   3. モデル比較              (一番強い。オラクルがあるなら最優先)
--   4. 往復・冪等性・局所性     (モデルがないとき、または補強として)
--   5. 分布の確認              (本当に試せているか)
--   6. 全域性                  (安全網)
--
-- ★ この実装にはわざと平衡化を入れていません。
--   ソート済みのリストを insert すると、片側に伸びた「リストのような木」になります。
--   それを検出するプロパティを書くとしたら:
--
--     prop_balanced t = depth t <= 2 * log2 (sizeT t + 1)
--
--   平衡木 (AVL, 赤黒木) を実装したら、このプロパティを追加してください。
--   上の実装では、このプロパティは当然落ちます。
