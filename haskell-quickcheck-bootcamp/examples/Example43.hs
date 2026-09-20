-- Example 43: 型クラス則を検査する
--
-- 自作の型に Functor / Applicative / Monad / Semigroup / Ord などの
-- インスタンスを書いたら、法則を満たしているか必ず確認してください。
-- 法則を破ったインスタンスは、使う側のコードを静かに壊します。
--
-- 実行: runghc Example43.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 題材1: 正しい Functor
------------------------------------------------------------
data Pair a = Pair a a
  deriving (Show, Eq)

instance Functor Pair where
  fmap f (Pair x y) = Pair (f x) (f y)

instance Arbitrary a => Arbitrary (Pair a) where
  arbitrary = Pair <$> arbitrary <*> arbitrary

-- Functor 則:
--   1. fmap id == id
--   2. fmap (f . g) == fmap f . fmap g
prop_pairFunctorId :: Pair Int -> Property
prop_pairFunctorId p = fmap id p === p

prop_pairFunctorCompose :: Fun Int Int -> Fun Int Int -> Pair Int -> Property
prop_pairFunctorCompose (Fn f) (Fn g) p =
  fmap (f . g) p === (fmap f . fmap g) p

------------------------------------------------------------
-- 題材2: 壊れた Functor
------------------------------------------------------------
-- 「2つ目を捨てて1つ目で埋める」実装。
-- これは Functor 則の第1法則だけを破り、第2法則は満たしてしまいます。
data BadPair a = BadPair a a
  deriving (Show, Eq)

instance Functor BadPair where
  fmap f (BadPair x _) = BadPair (f x) (f x)   -- ★ 2つ目を捨てている

instance Arbitrary a => Arbitrary (BadPair a) where
  arbitrary = BadPair <$> arbitrary <*> arbitrary

prop_badPairFunctorId :: BadPair Int -> Property
prop_badPairFunctorId p = fmap id p === p

-- ★ 第2法則 (合成) のほうは成り立ってしまいます。
--   fmap (f . g) (BadPair x _)      = BadPair (f (g x)) (f (g x))
--   fmap f (fmap g (BadPair x _))   = fmap f (BadPair (g x) (g x))
--                                   = BadPair (f (g x)) (f (g x))
--   どちらも同じなので、合成則だけでは、このバグを検出できません。
prop_badPairFunctorCompose :: Fun Int Int -> Fun Int Int -> BadPair Int -> Property
prop_badPairFunctorCompose (Fn f) (Fn g) p =
  fmap (f . g) p === (fmap f . fmap g) p

------------------------------------------------------------
-- 題材3: Semigroup / Monoid 則
------------------------------------------------------------
newtype MaxInt = MaxInt Int
  deriving (Show, Eq)

instance Semigroup MaxInt where
  MaxInt a <> MaxInt b = MaxInt (max a b)

instance Monoid MaxInt where
  mempty = MaxInt minBound

instance Arbitrary MaxInt where
  arbitrary = MaxInt <$> arbitrary

prop_maxAssoc :: MaxInt -> MaxInt -> MaxInt -> Property
prop_maxAssoc a b c = (a <> b) <> c === a <> (b <> c)

prop_maxLeftId :: MaxInt -> Property
prop_maxLeftId a = mempty <> a === a

prop_maxRightId :: MaxInt -> Property
prop_maxRightId a = a <> mempty === a

-- 壊れた Monoid: 単位元を間違えている
newtype BadMax = BadMax Int
  deriving (Show, Eq)

instance Semigroup BadMax where
  BadMax a <> BadMax b = BadMax (max a b)

instance Monoid BadMax where
  mempty = BadMax 0        -- ★ 負の数に対して単位元にならない

instance Arbitrary BadMax where
  arbitrary = BadMax <$> arbitrary

prop_badMaxLeftId :: BadMax -> Property
prop_badMaxLeftId a = mempty <> a === a

------------------------------------------------------------
-- 題材4: Ord 則 (全順序)
------------------------------------------------------------
data Version = Version Int Int Int
  deriving (Show, Eq)

instance Ord Version where
  compare (Version a b c) (Version x y z) = compare (a, b, c) (x, y, z)

instance Arbitrary Version where
  arbitrary = Version <$> choose (0, 5) <*> choose (0, 5) <*> choose (0, 5)

prop_ordReflexive :: Version -> Bool
prop_ordReflexive v = v <= v

prop_ordAntisymmetric :: Version -> Version -> Property
prop_ordAntisymmetric a b = (a <= b && b <= a) ==> a === b

prop_ordTransitive :: Version -> Version -> Version -> Property
prop_ordTransitive a b c = (a <= b && b <= c) ==> property (a <= c)

prop_ordTotal :: Version -> Version -> Bool
prop_ordTotal a b = a <= b || b <= a

-- 壊れた Ord: メジャーバージョンしか見ていない
newtype BadVersion = BadVersion Version
  deriving (Show, Eq)

instance Ord BadVersion where
  compare (BadVersion (Version a _ _)) (BadVersion (Version x _ _)) = compare a x

instance Arbitrary BadVersion where
  arbitrary = BadVersion <$> arbitrary

-- Eq と Ord の整合性: compare x y == EQ なら x == y であるべき
prop_badVersionEqConsistent :: BadVersion -> BadVersion -> Property
prop_badVersionEqConsistent a b =
  compare a b == EQ ==> a === b

main :: IO ()
main = do
  putStrLn "--- Functor laws: Pair (correct) ---"
  putStr "fmap id = id        : " >> quickCheck prop_pairFunctorId
  putStr "fmap (f.g) = ...    : " >> quickCheck prop_pairFunctorCompose

  putStrLn ""
  putStrLn "--- Functor laws: BadPair (drops the second element) ---"
  putStrLn "fmap id = id (fails on purpose):"
  quickCheck prop_badPairFunctorId
  putStr "fmap (f.g) = ...    : " >> quickCheck prop_badPairFunctorCompose
  putStrLn "  ^ the composition law PASSES even though the instance is wrong!"

  putStrLn ""
  putStrLn "--- Monoid laws: MaxInt (correct) ---"
  putStr "associative         : " >> quickCheck prop_maxAssoc
  putStr "left identity       : " >> quickCheck prop_maxLeftId
  putStr "right identity      : " >> quickCheck prop_maxRightId

  putStrLn ""
  putStrLn "--- Monoid laws: BadMax (mempty = 0) ---"
  putStrLn "left identity (fails on purpose):"
  quickCheck prop_badMaxLeftId

  putStrLn ""
  putStrLn "--- Ord laws: Version ---"
  putStr "reflexive           : " >> quickCheck prop_ordReflexive
  putStr "antisymmetric       : " >> quickCheck prop_ordAntisymmetric
  putStr "transitive          : " >> quickCheck prop_ordTransitive
  putStr "total               : " >> quickCheck prop_ordTotal

  putStrLn ""
  putStrLn "--- Ord/Eq consistency: BadVersion (fails on purpose) ---"
  quickCheck prop_badVersionEqConsistent

-- 法則の一覧 (自作インスタンスを書いたら順に確認):
--
--   Eq          反射律 / 対称律 / 推移律
--   Ord         反射律 / 反対称律 / 推移律 / 全域性 / Eq との整合
--   Semigroup   結合律
--   Monoid      左単位元 / 右単位元 / mconcat = foldr (<>) mempty
--   Functor     fmap id = id / fmap (f.g) = fmap f . fmap g
--   Applicative 単位元律 / 合成律 / 準同型律 / 交換律
--   Monad       左単位元 (return x >>= f = f x) / 右単位元 / 結合律
--
-- BadPair の例が示すとおり、法則を1つだけ確かめても足りません。
-- 全部書いてください。数は多くても、1つ1つは1行で書けます。
