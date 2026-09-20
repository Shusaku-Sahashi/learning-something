-- | Queue のプロパティ。
--
-- 並び順:
--   1. 生成器と縮小の検証
--   2. 表現不変条件
--   3. モデル比較 (コマンド列)
--   4. 個別の性質
module Props.Queue (group) where

import Bootcamp.Queue
import Gen.Queue
import Runner
import Test.QuickCheck

group :: Group
group = Group "Bootcamp.Queue"
  [ Prop "generator keeps invariant"  prop_genInvariant
  , Prop "shrink keeps invariant"     prop_shrinkInvariant
  , Prop "shrink is smaller"          prop_shrinkSmaller
  , Prop "push keeps invariant"       prop_pushInvariant
  , Prop "pop keeps invariant"        prop_popInvariant
  , Prop "fifo order"                 prop_fifo
  , Prop "size matches toList"        prop_size
  , Prop "push then toList"           prop_pushToList
  , Prop "command sequence vs model"  prop_commandSequence
  , Prop "toList/fromList round trip" prop_roundTrip
  , Prop "command coverage"           prop_coverage
  ]

------------------------------------------------------------
-- 1. 生成器と縮小
------------------------------------------------------------
prop_genInvariant :: Property
prop_genInvariant = forAll (genQueue :: Gen (Queue Int)) invariant

prop_shrinkInvariant :: Property
prop_shrinkInvariant =
  forAll (genQueue :: Gen (Queue Int)) (all invariant . shrinkQueue)

prop_shrinkSmaller :: Property
prop_shrinkSmaller =
  forAll (genQueue :: Gen (Queue Int)) (\q -> q `notElem` shrinkQueue q)

------------------------------------------------------------
-- 2. 表現不変条件が操作で保たれる
------------------------------------------------------------
prop_pushInvariant :: Int -> Property
prop_pushInvariant x =
  forAllShrink (genQueue :: Gen (Queue Int)) shrinkQueue (invariant . push x)

prop_popInvariant :: Property
prop_popInvariant =
  forAllShrink (genQueue :: Gen (Queue Int)) shrinkQueue $ \q ->
    case pop q of
      Nothing      -> property True
      Just (_, q') -> property (invariant q')

------------------------------------------------------------
-- 3. 個別の性質
------------------------------------------------------------
prop_fifo :: [Int] -> Property
prop_fifo xs = drain (fromList xs) === xs
  where
    drain q = case pop q of
      Nothing      -> []
      Just (x, q') -> x : drain q'

prop_size :: Property
prop_size =
  forAllShrink (genQueue :: Gen (Queue Int)) shrinkQueue $ \q ->
    size q === length (toList q)

prop_pushToList :: Int -> Property
prop_pushToList x =
  forAllShrink (genQueue :: Gen (Queue Int)) shrinkQueue $ \q ->
    toList (push x q) === toList q ++ [x]

prop_roundTrip :: [Int] -> Property
prop_roundTrip xs = toList (fromList xs) === xs

------------------------------------------------------------
-- 4. コマンド列によるモデル比較 (state machine テスト)
------------------------------------------------------------
data Cmd = Push Int | Pop | Size
  deriving (Show, Eq)

instance Arbitrary Cmd where
  arbitrary = frequency [ (4, Push <$> choose (0, 9)), (4, pure Pop), (1, pure Size) ]
  shrink (Push n) = [ Push n' | n' <- shrink n, n' >= 0 ]
  shrink _        = []

data Obs = OUnit | OPopped (Maybe Int) | OSize Int
  deriving (Show, Eq)

stepImpl :: Queue Int -> Cmd -> (Obs, Queue Int)
stepImpl q (Push n) = (OUnit, push n q)
stepImpl q Pop      = case pop q of
                        Nothing      -> (OPopped Nothing, q)
                        Just (x, q') -> (OPopped (Just x), q')
stepImpl q Size     = (OSize (size q), q)

stepModel :: [Int] -> Cmd -> (Obs, [Int])
stepModel m (Push n) = (OUnit, m ++ [n])
stepModel m Pop      = case m of
                         []       -> (OPopped Nothing, m)
                         (x : xs) -> (OPopped (Just x), xs)
stepModel m Size     = (OSize (length m), m)

runImpl :: [Cmd] -> ([Obs], [Queue Int])
runImpl = go empty
  where
    go _ []       = ([], [])
    go q (c : cs) = let (o, q')   = stepImpl q c
                        (os, qs)  = go q' cs
                    in (o : os, q' : qs)

runModel :: [Cmd] -> [Obs]
runModel = go []
  where
    go _ []       = []
    go m (c : cs) = let (o, m') = stepModel m c in o : go m' cs

prop_commandSequence :: Property
prop_commandSequence =
  forAllShrink (arbitrary :: Gen [Cmd]) shrink $ \cmds ->
    let (obs, states) = runImpl cmds
    in counterexample (unlines (map show (zip3 cmds obs (runModel cmds)))) $
         obs === runModel cmds .&&. property (all invariant states)

prop_coverage :: Property
prop_coverage =
  checkCoverage $
  forAll (arbitrary :: Gen [Cmd]) $ \cmds ->
    cover 40 (length cmds >= 4)             "4+ commands"     $
    cover 20 (popsWhileEmpty cmds > 0)      "pop when empty"  $
    cover 20 (length [ () | Push _ <- cmds ] >= 2) "2+ pushes" $
      True
  where
    popsWhileEmpty = go (0 :: Int) (0 :: Int)
      where
        go n _  []             = n
        go n sz (Push _ : cs)  = go n (sz + 1) cs
        go n 0  (Pop : cs)     = go (n + 1) 0 cs
        go n sz (Pop : cs)     = go n (sz - 1) cs
        go n sz (_ : cs)       = go n sz cs
