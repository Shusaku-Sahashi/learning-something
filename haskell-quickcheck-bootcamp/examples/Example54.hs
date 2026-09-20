-- Example 54: 再帰的な型の shrink
--
-- 木や式のような再帰型は、shrink の効果が一番大きく出る場所です。
-- 「部分構造そのものを候補にする」のが鍵です。
--
-- 実行: runghc Example54.hs
{-# LANGUAGE DeriveGeneric #-}
module Main (main) where

import GHC.Generics (Generic)
import Test.QuickCheck

------------------------------------------------------------
-- 式の型
------------------------------------------------------------
data Expr
  = Lit Int
  | Add Expr Expr
  | Mul Expr Expr
  deriving (Show, Eq, Generic)

eval :: Expr -> Int
eval (Lit n)   = n
eval (Add a b) = eval a + eval b
eval (Mul a b) = eval a * eval b

nodes :: Expr -> Int
nodes (Lit _)   = 1
nodes (Add a b) = 1 + nodes a + nodes b
nodes (Mul a b) = 1 + nodes a + nodes b

-- genericShrink は、フィールドの型にも Arbitrary を要求します。
-- Expr は自分自身をフィールドに持つので、Expr 自体の Arbitrary が必要です。
instance Arbitrary Expr where
  arbitrary = genExpr
  shrink    = genericShrink

genExpr :: Gen Expr
genExpr = sized go
  where
    go 0 = Lit <$> choose (0, 9)
    go n = frequency
      [ (1, Lit <$> choose (0, 9))
      , (2, Add <$> go (n `div` 2) <*> go (n `div` 2))
      , (2, Mul <$> go (n `div` 2) <*> go (n `div` 2))
      ]

------------------------------------------------------------
-- shrink なし
------------------------------------------------------------
newtype NoShrinkExpr = NoShrinkExpr Expr
  deriving (Show, Eq)

instance Arbitrary NoShrinkExpr where
  arbitrary = NoShrinkExpr <$> genExpr

------------------------------------------------------------
-- 手書きの shrink
------------------------------------------------------------
newtype ManualExpr = ManualExpr Expr
  deriving (Show, Eq)

shrinkExpr :: Expr -> [Expr]
shrinkExpr (Lit n)   = [ Lit n' | n' <- shrink n ]
shrinkExpr (Add a b) =
  -- 定石1: 部分式そのものを候補にする (一番効く)
  [ a, b ] ++
  -- 定石2: もっと単純なコンストラクタに落とす
  [ Lit 0 ] ++
  -- 定石3: 部分式を縮めた同じ形
  [ Add a' b | a' <- shrinkExpr a ] ++
  [ Add a b' | b' <- shrinkExpr b ]
shrinkExpr (Mul a b) =
  [ a, b ] ++
  [ Lit 0, Add a b ] ++
  [ Mul a' b | a' <- shrinkExpr a ] ++
  [ Mul a b' | b' <- shrinkExpr b ]

instance Arbitrary ManualExpr where
  arbitrary = ManualExpr <$> genExpr
  shrink (ManualExpr e) = [ ManualExpr e' | e' <- shrinkExpr e ]

------------------------------------------------------------
-- genericShrink
------------------------------------------------------------
newtype GenericExpr = GenericExpr Expr
  deriving (Show, Eq)

instance Arbitrary GenericExpr where
  arbitrary = GenericExpr <$> genExpr
  shrink (GenericExpr e) = [ GenericExpr e' | e' <- genericShrink e ]

------------------------------------------------------------
-- わざと失敗するプロパティ: 「式の値は 20 未満」
------------------------------------------------------------
prop_noShrink :: NoShrinkExpr -> Property
prop_noShrink (NoShrinkExpr e) =
  counterexample ("eval = " ++ show (eval e) ++ ", nodes = " ++ show (nodes e))
    (eval e < 20)

prop_manual :: ManualExpr -> Property
prop_manual (ManualExpr e) =
  counterexample ("eval = " ++ show (eval e) ++ ", nodes = " ++ show (nodes e))
    (eval e < 20)

prop_generic :: GenericExpr -> Property
prop_generic (GenericExpr e) =
  counterexample ("eval = " ++ show (eval e) ++ ", nodes = " ++ show (nodes e))
    (eval e < 20)

------------------------------------------------------------
-- shrink の契約チェック
------------------------------------------------------------
prop_shrinkSmaller :: ManualExpr -> Bool
prop_shrinkSmaller m@(ManualExpr _) = m `notElem` shrink m

prop_shrinkReducesNodes :: ManualExpr -> Bool
prop_shrinkReducesNodes (ManualExpr e) =
  all (\e' -> nodes e' <= nodes e) (shrinkExpr e)

main :: IO ()
main = do
  putStrLn "--- shrink candidates for  Add (Mul (Lit 2) (Lit 3)) (Lit 4) ---"
  let e = Add (Mul (Lit 2) (Lit 3)) (Lit 4)
  mapM_ (putStrLn . ("  " ++) . show) (take 8 (shrinkExpr e))
  putStrLn ""

  putStrLn "--- genericShrink candidates for the same expression ---"
  mapM_ (putStrLn . ("  " ++) . show) (take 8 (genericShrink e))
  putStrLn ""

  putStrLn "=== WITHOUT shrinking ==="
  quickCheck prop_noShrink
  putStrLn ""

  putStrLn "=== manual shrink ==="
  quickCheck prop_manual
  putStrLn ""

  putStrLn "=== genericShrink ==="
  quickCheck prop_generic
  putStrLn ""

  putStrLn "--- shrink contract ---"
  putStr "no self in candidates : " >> quickCheck prop_shrinkSmaller
  putStr "node count does not grow : " >> quickCheck prop_shrinkReducesNodes

-- 3つの結果を見比べてください (乱数なので実行ごとに変わります)。
--   shrink なし   : 生成された式がそのまま報告される。
--                   運が悪いと数十ノードの木がそのまま出てくる。
--   手書き        : Mul (Lit 4) (Lit 5) のような 3 ノードの最小形まで縮む
--   genericShrink : 手書きと同等のところまで縮む
--
-- maxSize を上げると差が劇的になります。試してみてください:
--   quickCheckWith stdArgs { maxSize = 40 } prop_noShrink
--   quickCheckWith stdArgs { maxSize = 40 } prop_manual
--
-- 再帰型の shrink で一番効くのは「部分構造を候補に入れる」ことです。
--
--   shrink (Add a b) = [a, b] ++ ...
--
-- この1行で、木の大きさが一気に半分以下になります。
-- genericShrink はこれを自動でやってくれるので、
-- 不変条件がない再帰型なら genericShrink で十分なことが多いです。
