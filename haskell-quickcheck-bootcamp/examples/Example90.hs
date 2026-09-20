-- Example 90: パーサと pretty printer の往復
--
-- Example 11-12 で扱った往復プロパティを、
-- 優先順位と括弧のある本格的な言語でやります。
--
-- 実行: runghc Example90.hs
module Main (main) where

import Data.Char (isDigit, isSpace, isAlpha)
import Test.QuickCheck

------------------------------------------------------------
-- 式の構文
------------------------------------------------------------
data Expr
  = Num Int
  | Var String
  | Add Expr Expr
  | Sub Expr Expr
  | Mul Expr Expr
  | Neg Expr
  deriving (Show, Eq)

------------------------------------------------------------
-- 生成器
------------------------------------------------------------
instance Arbitrary Expr where
  arbitrary = sized go
    where
      leaf = oneof [ Num <$> choose (0, 99)
                   , Var <$> elements ["x", "y", "z", "n"] ]
      go 0 = leaf
      go n = frequency
        [ (3, leaf)
        , (2, Add <$> go (n `div` 2) <*> go (n `div` 2))
        , (2, Sub <$> go (n `div` 2) <*> go (n `div` 2))
        , (2, Mul <$> go (n `div` 2) <*> go (n `div` 2))
        , (1, Neg <$> go (n - 1))
        ]

  -- 部分式そのものを候補にする (Ch5 の定石)
  shrink (Num n)   = [ Num n' | n' <- shrink n, n' >= 0 ]
  shrink (Var _)   = [ Num 0 ]
  shrink (Add a b) = [ a, b, Num 0 ] ++ [ Add a' b | a' <- shrink a ] ++ [ Add a b' | b' <- shrink b ]
  shrink (Sub a b) = [ a, b, Num 0 ] ++ [ Sub a' b | a' <- shrink a ] ++ [ Sub a b' | b' <- shrink b ]
  shrink (Mul a b) = [ a, b, Num 0 ] ++ [ Mul a' b | a' <- shrink a ] ++ [ Mul a b' | b' <- shrink b ]
  shrink (Neg a)   = [ a, Num 0 ] ++ [ Neg a' | a' <- shrink a ]

------------------------------------------------------------
-- pretty printer: 必要なところにだけ括弧をつける
------------------------------------------------------------
-- 優先順位: Add/Sub = 1, Mul = 2, Neg = 3, リテラル = 4
prec :: Expr -> Int
prec (Num _)   = 4
prec (Var _)   = 4
prec (Neg _)   = 3
prec (Mul _ _) = 2
prec (Add _ _) = 1
prec (Sub _ _) = 1

render :: Expr -> String
render = go 0
  where
    go ctx e =
      let s = body e
      in if prec e < ctx then "(" ++ s ++ ")" else s

    body (Num n)   = show n
    body (Var v)   = v
    body (Neg a)   = "-" ++ go 4 a
    body (Mul a b) = go 2 a ++ " * " ++ go 3 b
    body (Add a b) = go 1 a ++ " + " ++ go 2 b
    body (Sub a b) = go 1 a ++ " - " ++ go 2 b

------------------------------------------------------------
-- パーサ (再帰下降)
------------------------------------------------------------
type P a = String -> Maybe (a, String)

skipWs :: String -> String
skipWs = dropWhile isSpace

parseExpr :: String -> Maybe Expr
parseExpr s = case pAddSub (skipWs s) of
  Just (e, rest) | null (skipWs rest) -> Just e
  _                                   -> Nothing

pAddSub :: P Expr
pAddSub s = do
  (first, r) <- pMul s
  loop first r
  where
    loop acc r = case skipWs r of
      ('+' : r') -> do (t, r'') <- pMul (skipWs r'); loop (Add acc t) r''
      ('-' : r') -> do (t, r'') <- pMul (skipWs r'); loop (Sub acc t) r''
      _          -> Just (acc, r)

pMul :: P Expr
pMul s = do
  (first, r) <- pUnary s
  loop first r
  where
    loop acc r = case skipWs r of
      ('*' : r') -> do (t, r'') <- pUnary (skipWs r'); loop (Mul acc t) r''
      _          -> Just (acc, r)

pUnary :: P Expr
pUnary s = case skipWs s of
  ('-' : r) -> do (e, r') <- pUnary (skipWs r); Just (Neg e, r')
  s'        -> pAtom s'

pAtom :: P Expr
pAtom s = case skipWs s of
  ('(' : r) -> do
    (e, r') <- pAddSub (skipWs r)
    case skipWs r' of
      (')' : r'') -> Just (e, r'')
      _           -> Nothing
  s'@(c : _)
    | isDigit c -> let (ds, r) = span isDigit s' in Just (Num (read ds), r)
    | isAlpha c -> let (vs, r) = span isAlpha s' in Just (Var vs, r)
  _ -> Nothing

------------------------------------------------------------
-- 評価器 (別の視点からの検証に使う)
------------------------------------------------------------
eval :: [(String, Int)] -> Expr -> Int
eval env e = case e of
  Num n   -> n
  Var v   -> maybe 0 id (lookup v env)
  Add a b -> eval env a + eval env b
  Sub a b -> eval env a - eval env b
  Mul a b -> eval env a * eval env b
  Neg a   -> negate (eval env a)

------------------------------------------------------------
-- プロパティ
------------------------------------------------------------
-- 本命: 書き出して読み戻すと元に戻る
prop_roundTrip :: Expr -> Property
prop_roundTrip e =
  counterexample ("rendered: " ++ render e) $
  counterexample ("parsed  : " ++ show (parseExpr (render e))) $
    parseExpr (render e) === Just e

-- パーサは何を渡しても落ちない
prop_parseTotal :: String -> Property
prop_parseTotal s = total (fmap render (parseExpr s))

-- 括弧を足しても意味は変わらない
prop_extraParens :: Expr -> Property
prop_extraParens e =
  parseExpr ("(" ++ render e ++ ")") === Just e

-- 空白をたくさん入れても読める
prop_whitespaceTolerant :: Expr -> Property
prop_whitespaceTolerant e =
  parseExpr (spaceOut (render e)) === Just e
  where
    spaceOut = concatMap (\c -> if c `elem` "+-*()" then "  " ++ [c] ++ "  " else [c])

-- 評価結果も往復で保存される (別の角度からの検証)
prop_evalPreserved :: Expr -> Property
prop_evalPreserved e =
  let env = [("x", 3), ("y", 5), ("z", 7), ("n", 11)]
  in case parseExpr (render e) of
       Just e' -> eval env e' === eval env e
       Nothing -> counterexample ("failed to parse: " ++ render e) (property False)

-- 括弧の数は必要最小限か (pretty printer の品質)
prop_noRedundantParensOnLeaves :: Property
prop_noRedundantParensOnLeaves =
  conjoin
    [ counterexample (show e) (render e === expected)
    | (e, expected) <-
        [ (Num 1,                              "1")
        , (Add (Num 1) (Num 2),                "1 + 2")
        , (Mul (Add (Num 1) (Num 2)) (Num 3),  "(1 + 2) * 3")
        , (Add (Mul (Num 1) (Num 2)) (Num 3),  "1 * 2 + 3")
        , (Sub (Num 1) (Add (Num 2) (Num 3)),  "1 - (2 + 3)")
        , (Neg (Add (Num 1) (Num 2)),          "-(1 + 2)")
        , (Mul (Neg (Num 1)) (Num 2),          "-1 * 2")
        ]
    ]

main :: IO ()
main = do
  putStrLn "--- sample expressions ---"
  es <- sample' (arbitrary :: Gen Expr)
  mapM_ (putStrLn . ("  " ++) . render) (take 8 es)
  putStrLn ""

  putStrLn "--- properties ---"
  putStr "round trip          : " >> quickCheckWith stdArgs { maxSuccess = 1000 } prop_roundTrip
  putStr "parser is total     : " >> quickCheck prop_parseTotal
  putStr "extra parens ok     : " >> quickCheck prop_extraParens
  putStr "whitespace tolerant : " >> quickCheck prop_whitespaceTolerant
  putStr "eval preserved      : " >> quickCheck prop_evalPreserved
  putStr "printer is minimal  : " >> quickCheck prop_noRedundantParensOnLeaves
  putStrLn ""

  putStrLn "--- concrete examples ---"
  mapM_ showOne
    [ Add (Num 1) (Mul (Num 2) (Num 3))
    , Mul (Add (Num 1) (Num 2)) (Num 3)
    , Sub (Num 1) (Sub (Num 2) (Num 3))
    , Neg (Mul (Var "x") (Add (Num 1) (Var "y")))
    ]
  where
    showOne e = do
      let s = render e
      putStrLn ("  " ++ pad 24 s ++ "-> " ++ show (parseExpr s == Just e))
    pad n s = s ++ replicate (n - length s) ' '

-- なぜ往復プロパティが強力なのか:
--
--   render と parse の両方を同時に検査できます。
--   * 括弧を付け忘れれば、parse した結果の構造が変わって落ちる
--   * 括弧を付けすぎても、parse は成功するので落ちない
--     (そこは prop_noRedundantParensOnLeaves のような例示テストで補う)
--   * 優先順位の実装ミスは、ほぼ確実に落ちる
--
-- ★ 注意したい非対称性
--
--   parse (render e) == Just e     ... ほぼ常に成り立つべき
--   render (parse s) == Just s     ... 成り立たない (空白や余分な括弧が落ちる)
--
--   どちら向きが成り立つのかを意識してください。
--   「正規化されたテキストなら双方向に成り立つ」という形にもできます:
--
--     prop_normalised s = case parseExpr s of
--       Nothing -> discard
--       Just e  -> parseExpr (render e) === Just e
--
-- ★ Sub の結合性に注意
--
--   render (Sub (Num 1) (Sub (Num 2) (Num 3))) は "1 - (2 - 3)" になります。
--   括弧を外して "1 - 2 - 3" にすると、左結合で解釈されて別の式になります。
--   render の body で go 2 b (右側は1段強い文脈) としているのは、
--   まさにこれを防ぐためです。
--   ここを go 1 b にすると、prop_roundTrip が落ちます。試してみてください。
