-- Example 34: 再帰的なデータ型 (2) sized の書き方を身につける
--
-- Example 33 で見た sized のパターンを、いくつかの形で練習します。
--
-- 実行: runghc Example34.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 型1: 算術式
------------------------------------------------------------
data Expr
  = Lit Int
  | Add Expr Expr
  | Mul Expr Expr
  | Neg Expr
  deriving (Show, Eq)

eval :: Expr -> Int
eval (Lit n)   = n
eval (Add a b) = eval a + eval b
eval (Mul a b) = eval a * eval b
eval (Neg a)   = negate (eval a)

nodes :: Expr -> Int
nodes (Lit _)   = 1
nodes (Add a b) = 1 + nodes a + nodes b
nodes (Mul a b) = 1 + nodes a + nodes b
nodes (Neg a)   = 1 + nodes a

instance Arbitrary Expr where
  arbitrary = sized go
    where
      -- サイズ 0 では必ず終端 (Lit) を返す
      go 0 = Lit <$> choose (-20, 20)
      go n = frequency
        [ (1, Lit <$> choose (-20, 20))
        -- 2項演算はサイズを半分ずつに分ける
        , (2, Add <$> go half <*> go half)
        , (2, Mul <$> go half <*> go half)
        -- 1項演算はサイズを 1 減らす
        , (1, Neg <$> go (n - 1))
        ]
        where half = n `div` 2

------------------------------------------------------------
-- 型2: ネストしたリスト (JSON の配列のような形)
------------------------------------------------------------
data Nested
  = Atom Int
  | List [Nested]
  deriving (Show, Eq)

flatten :: Nested -> [Int]
flatten (Atom n)  = [n]
flatten (List ns) = concatMap flatten ns

instance Arbitrary Nested where
  arbitrary = sized go
    where
      go 0 = Atom <$> arbitrary
      go n = frequency
        [ (1, Atom <$> arbitrary)
        -- 子の個数 k を決めて、サイズを k で割って配る
        , (3, do k <- choose (0, 4)
                 List <$> vectorOf k (go (n `div` (k + 1))))
        ]

------------------------------------------------------------
-- 型3: 相互再帰する型
------------------------------------------------------------
data Stmt
  = Assign String Expr
  | If Expr Block Block
  | While Expr Block
  deriving (Show)

newtype Block = Block [Stmt]
  deriving (Show)

stmtCount :: Block -> Int
stmtCount (Block ss) = sum (map go ss)
  where
    go (Assign _ _)   = 1
    go (If _ b1 b2)   = 1 + stmtCount b1 + stmtCount b2
    go (While _ b)    = 1 + stmtCount b

instance Arbitrary Stmt where
  arbitrary = sized goStmt

instance Arbitrary Block where
  arbitrary = sized goBlock

goStmt :: Int -> Gen Stmt
goStmt 0 = Assign <$> genVar <*> (Lit <$> choose (0, 9))
goStmt n = frequency
  [ (3, Assign <$> genVar <*> resize (n `div` 2) arbitrary)
  , (1, If <$> resize 2 arbitrary <*> goBlock (n `div` 2) <*> goBlock (n `div` 2))
  , (1, While <$> resize 2 arbitrary <*> goBlock (n `div` 2))
  ]

goBlock :: Int -> Gen Block
goBlock 0 = pure (Block [])
goBlock n = do
  k <- choose (0, 3)
  Block <$> vectorOf k (goStmt (n `div` (k + 1)))

genVar :: Gen String
genVar = (: []) <$> elements ['a' .. 'e']

------------------------------------------------------------
-- プロパティ
------------------------------------------------------------
prop_exprTerminates :: Expr -> Bool
prop_exprTerminates e = nodes e >= 1

prop_evalNegTwice :: Expr -> Property
prop_evalNegTwice e = eval (Neg (Neg e)) === eval e

prop_addCommutes :: Expr -> Expr -> Property
prop_addCommutes a b = eval (Add a b) === eval (Add b a)

prop_flattenNonEmpty :: Nested -> Bool
prop_flattenNonEmpty n = length (flatten n) >= 0

prop_blockFinite :: Block -> Bool
prop_blockFinite b = stmtCount b >= 0

main :: IO ()
main = do
  putStrLn "--- Expr ---"
  es <- sample' (arbitrary :: Gen Expr)
  mapM_ print (take 5 es)
  putStrLn ("  node counts: " ++ show (map nodes es))

  putStrLn ""
  putStrLn "--- Nested ---"
  ns <- sample' (arbitrary :: Gen Nested)
  mapM_ print (take 4 ns)

  putStrLn ""
  putStrLn "--- Block (mutually recursive) ---"
  bs <- sample' (arbitrary :: Gen Block)
  mapM_ print (take 3 bs)
  putStrLn ("  statement counts: " ++ show (map stmtCount bs))

  putStrLn ""
  putStrLn "--- properties ---"
  putStr "expr terminates  : " >> quickCheck prop_exprTerminates
  putStr "neg . neg = id   : " >> quickCheck prop_evalNegTwice
  putStr "add commutes     : " >> quickCheck prop_addCommutes
  putStr "flatten total    : " >> quickCheck prop_flattenNonEmpty
  putStr "block finite     : " >> quickCheck prop_blockFinite

-- サイズの配り方のパターン:
--
--   1項演算 (Neg e)          : go (n - 1)
--   2項演算 (Add a b)        : go (n `div` 2) を2回
--   k 個の子 (List [n1..nk]) : go (n `div` (k + 1)) を k 回
--
-- どれも「子のサイズの合計が親より小さい」ようにするのがポイントです。
-- こうすれば再帰は必ず 0 にたどり着きます。
--
-- 相互再帰する型では、片方が sized、もう片方が resize を使う形になりがちです。
-- 上の Stmt / Block のように、サイズを引数に取るヘルパー関数
-- (goStmt / goBlock) を定義して、instance からはそれを呼ぶ形にすると
-- 見通しが良くなります。
