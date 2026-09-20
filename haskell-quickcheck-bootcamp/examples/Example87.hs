-- Example 87: モデルベーステスト入門
--
-- 「速いが複雑な実装」を「遅いが明らかに正しいモデル」と比べます。
-- Example 16 のオラクル法を、状態を持つデータ構造に広げたものです。
--
-- 実行: runghc Example87.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 実装: 2つのリストで作る償却 O(1) のキュー
------------------------------------------------------------
-- front には先頭側、back には末尾側を逆順で持ちます。
data Queue a = Queue [a] [a]

instance Show a => Show (Queue a) where
  show q = "Queue " ++ show (toListQ q)

emptyQ :: Queue a
emptyQ = Queue [] []

-- 不変条件: front が空なら back も空 (そうでないと head が O(n) になる)
invariant :: Queue a -> Bool
invariant (Queue [] back) = null back
invariant _               = True

mkQueue :: [a] -> [a] -> Queue a
mkQueue [] back = Queue (reverse back) []
mkQueue front back = Queue front back

pushQ :: a -> Queue a -> Queue a
pushQ x (Queue front back) = mkQueue front (x : back)

popQ :: Queue a -> Maybe (a, Queue a)
popQ (Queue [] _)            = Nothing
popQ (Queue (x : front) back) = Just (x, mkQueue front back)

sizeQ :: Queue a -> Int
sizeQ (Queue front back) = length front + length back

toListQ :: Queue a -> [a]
toListQ (Queue front back) = front ++ reverse back

-- 注: foldl は Foldable 上で多相なので、instance の中で
--     foldl (flip pushQ) emptyQ <$> arbitrary と書くと型が曖昧になります。
--     リスト専用のヘルパーを1つ用意しておくと、そこで型が決まります。
fromListQ :: [a] -> Queue a
fromListQ = foldl (flip pushQ) emptyQ

------------------------------------------------------------
-- モデル: ただのリスト (明らかに正しい)
------------------------------------------------------------
type Model a = [a]

emptyM :: Model a
emptyM = []

pushM :: a -> Model a -> Model a
pushM x m = m ++ [x]

popM :: Model a -> Maybe (a, Model a)
popM []       = Nothing
popM (x : xs) = Just (x, xs)

sizeM :: Model a -> Int
sizeM = length

------------------------------------------------------------
-- 抽象化関数: 実装 -> モデル
------------------------------------------------------------
abstract :: Queue a -> Model a
abstract = toListQ

------------------------------------------------------------
-- 生成: ランダムなキューを作る
------------------------------------------------------------
instance Arbitrary a => Arbitrary (Queue a) where
  arbitrary = fromListQ <$> arbitrary
  shrink q  = [ fromListQ xs | xs <- shrink (toListQ q) ]

------------------------------------------------------------
-- プロパティ: 各操作がモデルと一致する
------------------------------------------------------------
-- 「実装の操作 -> 抽象化」と「抽象化 -> モデルの操作」が一致すること。
-- これを可換図式 (commuting diagram) と呼びます。
--
--      Queue  --push-->  Queue
--        |                 |
--     abstract          abstract
--        |                 |
--        v                 v
--      Model  --pushM-->  Model

prop_emptyMatches :: Property
prop_emptyMatches = abstract (emptyQ :: Queue Int) === emptyM

prop_pushMatches :: Int -> Queue Int -> Property
prop_pushMatches x q = abstract (pushQ x q) === pushM x (abstract q)

prop_popMatches :: Queue Int -> Property
prop_popMatches q =
  case (popQ q, popM (abstract q)) of
    (Nothing, Nothing)            -> property True
    (Just (a, q'), Just (b, m'))  -> a === b .&&. abstract q' === m'
    (impl, model)                 ->
      counterexample (show (fmap fst impl, fmap fst model)) (property False)

prop_sizeMatches :: Queue Int -> Property
prop_sizeMatches q = sizeQ q === sizeM (abstract q)

------------------------------------------------------------
-- 不変条件: 操作しても壊れない
------------------------------------------------------------
prop_invariantHolds :: Queue Int -> Bool
prop_invariantHolds = invariant

prop_pushKeepsInvariant :: Int -> Queue Int -> Bool
prop_pushKeepsInvariant x q = invariant (pushQ x q)

prop_popKeepsInvariant :: Queue Int -> Bool
prop_popKeepsInvariant q = case popQ q of
  Nothing      -> True
  Just (_, q') -> invariant q'

prop_generatorKeepsInvariant :: Queue Int -> Bool
prop_generatorKeepsInvariant = invariant

prop_shrinkKeepsInvariant :: Queue Int -> Bool
prop_shrinkKeepsInvariant q = all invariant (shrink q)

------------------------------------------------------------
-- FIFO であること
------------------------------------------------------------
prop_fifo :: [Int] -> Property
prop_fifo xs =
  drain (fromListQ xs) === xs
  where
    drain q = case popQ q of
      Nothing      -> []
      Just (x, q') -> x : drain q'

main :: IO ()
main = do
  putStrLn "--- sample queues ---"
  qs <- sample' (arbitrary :: Gen (Queue Int))
  mapM_ print (take 5 qs)
  putStrLn ""

  putStrLn "--- each operation matches the model ---"
  putStr "empty  : " >> quickCheck prop_emptyMatches
  putStr "push   : " >> quickCheck prop_pushMatches
  putStr "pop    : " >> quickCheck prop_popMatches
  putStr "size   : " >> quickCheck prop_sizeMatches
  putStrLn ""

  putStrLn "--- the representation invariant is preserved ---"
  putStr "generator : " >> quickCheck prop_generatorKeepsInvariant
  putStr "shrink    : " >> quickCheck prop_shrinkKeepsInvariant
  putStr "push      : " >> quickCheck prop_pushKeepsInvariant
  putStr "pop       : " >> quickCheck prop_popKeepsInvariant
  putStrLn ""

  putStr "FIFO order : " >> quickCheck prop_fifo

-- モデルベーステストの型:
--
--   1. モデル (単純で明らかに正しい実装) を用意する
--   2. 抽象化関数 abstract :: Impl -> Model を書く
--   3. 各操作について「可換図式」をプロパティにする
--        abstract (op impl) === opM (abstract impl)
--   4. 表現不変条件 (representation invariant) もプロパティにする
--
-- これだけで、データ構造の正しさをかなり強く保証できます。
--
-- ただしこの Example にはまだ弱点があります。
-- 各操作を「1回だけ」試しているので、
-- 「push, pop, push, pop, ... の順で呼んだときだけ壊れる」バグは見つかりません。
--
-- そこで次の Example 88 では「操作の列」を生成します。
-- これがいわゆる state machine テストです。
