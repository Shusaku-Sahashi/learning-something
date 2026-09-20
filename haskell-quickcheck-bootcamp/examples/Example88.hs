-- Example 88: コマンド列を生成する (state machine テスト)
--
-- Example 87 では、各操作を「1回だけ」モデルと比べました。
-- ここでは「操作の列」を生成して、順番に適用します。
-- これが state machine テスト (モデルベースのステートフルテスト) です。
--
-- 実行: runghc Example88.hs
module Main (main) where

import Data.List (intercalate)
import Test.QuickCheck

------------------------------------------------------------
-- 実装: 2つのリストによるキュー
------------------------------------------------------------
data Queue a = Queue [a] [a]
  deriving (Eq)

instance Show a => Show (Queue a) where
  show (Queue f b) = "Queue " ++ show f ++ " " ++ show b

emptyQ :: Queue a
emptyQ = Queue [] []

-- 表現不変条件: front が空なら back も空
invariant :: Queue a -> Bool
invariant (Queue [] back) = null back
invariant _               = True

mkQueue :: [a] -> [a] -> Queue a
mkQueue []    back = Queue (reverse back) []
mkQueue front back = Queue front back

pushQ :: a -> Queue a -> Queue a
pushQ x (Queue front back) = mkQueue front (x : back)

sizeQ :: Queue a -> Int
sizeQ (Queue front back) = length front + length back

toListQ :: Queue a -> [a]
toListQ (Queue front back) = front ++ reverse back

-- 正しい pop: front が空になったら mkQueue で作り直す
popQ :: Queue a -> Maybe (a, Queue a)
popQ (Queue [] _)             = Nothing
popQ (Queue (x : front) back) = Just (x, mkQueue front back)

-- ★ バグ入りの pop: mkQueue を通さず、そのまま Queue を作る。
--   front が空で back が空でない状態ができてしまい、
--   次の pop が Nothing を返す。
popQBuggy :: Queue a -> Maybe (a, Queue a)
popQBuggy (Queue [] _)             = Nothing
popQBuggy (Queue (x : front) back) = Just (x, Queue front back)

------------------------------------------------------------
-- モデル: ただのリスト
------------------------------------------------------------
type Model = [Int]

------------------------------------------------------------
-- コマンド
------------------------------------------------------------
data Cmd
  = Push Int
  | Pop
  | Size
  | IsEmpty
  deriving (Eq)

instance Show Cmd where
  show (Push n) = "Push " ++ show n
  show Pop      = "Pop"
  show Size     = "Size"
  show IsEmpty  = "IsEmpty"

instance Arbitrary Cmd where
  arbitrary = frequency
    [ (4, Push <$> choose (0, 9))
    , (4, pure Pop)
    , (1, pure Size)
    , (1, pure IsEmpty)
    ]
  shrink (Push n) = [ Push n' | n' <- shrink n ]
  shrink _        = []

------------------------------------------------------------
-- 観測結果: コマンドを実行したときに「外から見える値」
------------------------------------------------------------
data Obs
  = OUnit                 -- Push は何も返さない
  | OPopped (Maybe Int)   -- Pop が返した値
  | OSize Int
  | OEmpty Bool
  deriving (Eq, Show)

------------------------------------------------------------
-- 実装側でコマンドを1つ実行する
------------------------------------------------------------
stepImpl :: (Queue Int -> Maybe (Int, Queue Int)) -> Queue Int -> Cmd -> (Obs, Queue Int)
stepImpl _   q (Push n) = (OUnit, pushQ n q)
stepImpl pop q Pop      = case pop q of
                            Nothing      -> (OPopped Nothing, q)
                            Just (x, q') -> (OPopped (Just x), q')
stepImpl _   q Size     = (OSize (sizeQ q), q)
stepImpl _   q IsEmpty  = (OEmpty (sizeQ q == 0), q)

------------------------------------------------------------
-- モデル側でコマンドを1つ実行する
------------------------------------------------------------
stepModel :: Model -> Cmd -> (Obs, Model)
stepModel m (Push n) = (OUnit, m ++ [n])
stepModel m Pop      = case m of
                         []       -> (OPopped Nothing, m)
                         (x : xs) -> (OPopped (Just x), xs)
stepModel m Size     = (OSize (length m), m)
stepModel m IsEmpty  = (OEmpty (null m), m)

------------------------------------------------------------
-- コマンド列を両方に流して、観測結果を比べる
------------------------------------------------------------
runImpl :: (Queue Int -> Maybe (Int, Queue Int)) -> [Cmd] -> ([Obs], [Queue Int])
runImpl pop = go emptyQ
  where
    go _ []         = ([], [])
    go q (c : cs)   = let (o, q') = stepImpl pop q c
                          (os, qs) = go q' cs
                      in (o : os, q' : qs)

runModel :: [Cmd] -> [Obs]
runModel = go []
  where
    go _ []       = []
    go m (c : cs) = let (o, m') = stepModel m c in o : go m' cs

------------------------------------------------------------
-- 反例を読みやすくするトレース表示
------------------------------------------------------------
trace :: (Queue Int -> Maybe (Int, Queue Int)) -> [Cmd] -> String
trace pop cmds =
  intercalate "\n"
    [ "    " ++ pad 10 (show c)
        ++ " impl=" ++ pad 18 (show oi)
        ++ " model=" ++ pad 18 (show om)
        ++ (if oi == om then "" else "   <-- MISMATCH")
        ++ "  state=" ++ show q
    | (c, oi, om, q) <- zip4 cmds (fst (runImpl pop cmds)) (runModel cmds) (snd (runImpl pop cmds))
    ]
  where
    pad n s = s ++ replicate (n - length s) ' '
    zip4 (a:as) (b:bs) (c:cs) (d:ds) = (a, b, c, d) : zip4 as bs cs ds
    zip4 _ _ _ _ = []

------------------------------------------------------------
-- プロパティ
------------------------------------------------------------
-- 本命: 観測結果の列がモデルと一致する
prop_sequenceMatches
  :: (Queue Int -> Maybe (Int, Queue Int)) -> [Cmd] -> Property
prop_sequenceMatches pop cmds =
  counterexample (trace pop cmds) $
    fst (runImpl pop cmds) === runModel cmds

-- 表現不変条件が、どの時点でも保たれている
prop_invariantAlways
  :: (Queue Int -> Maybe (Int, Queue Int)) -> [Cmd] -> Property
prop_invariantAlways pop cmds =
  counterexample (trace pop cmds) $
    all invariant (snd (runImpl pop cmds))

-- 参考: Example 87 と同じ「1回だけ」のプロパティ
instance Arbitrary (Queue Int) where
  arbitrary = foldl (flip pushQ) emptyQ <$> (arbitrary :: Gen [Int])
  shrink q  = [ foldl (flip pushQ) emptyQ xs | xs <- shrink (toListQ q) ]

prop_singlePopMatches
  :: (Queue Int -> Maybe (Int, Queue Int)) -> Queue Int -> Property
prop_singlePopMatches pop q =
  case (pop q, toListQ q) of
    (Nothing, [])            -> property True
    (Just (x, q'), (y : ys)) -> x === y .&&. toListQ q' === ys
    (impl, model)            ->
      counterexample (show (fmap fst impl, model)) (property False)

-- コマンドの分布を確認する (Ch7)
prop_commandCoverage :: Property
prop_commandCoverage =
  checkCoverage $
  forAll (arbitrary :: Gen [Cmd]) $ \cmds ->
    let popsOnEmpty = countPopsOnEmpty cmds
    in cover 30 (length cmds >= 5)  "5 or more commands" $
       cover 20 (popsOnEmpty > 0)   "pops an empty queue" $
       cover 20 (hasPushPopPush cmds) "push, pop, push pattern" $
         True

countPopsOnEmpty :: [Cmd] -> Int
countPopsOnEmpty = go (0 :: Int) (0 :: Int)
  where
    go n _ []            = n
    go n sz (Push _ : cs) = go n (sz + 1) cs
    go n 0  (Pop : cs)    = go (n + 1) 0 cs
    go n sz (Pop : cs)    = go n (sz - 1) cs
    go n sz (_ : cs)      = go n sz cs

hasPushPopPush :: [Cmd] -> Bool
hasPushPopPush (Push _ : Pop : Push _ : _) = True
hasPushPopPush (_ : cs)                    = hasPushPopPush cs
hasPushPopPush []                          = False

main :: IO ()
main = do
  putStrLn "--- sample command sequences ---"
  cs <- sample' (arbitrary :: Gen [Cmd])
  mapM_ (putStrLn . ("  " ++) . show) (take 5 cs)
  putStrLn ""

  putStrLn "=== the BUGGY implementation ==="
  putStrLn "single-operation property (as in Example 87):"
  quickCheck (prop_singlePopMatches popQBuggy)
  putStrLn "  ^ PASSES. One pop at a time never reveals the bug."
  putStrLn ""
  putStrLn "command-sequence property:"
  quickCheck (prop_sequenceMatches popQBuggy)
  putStrLn ""
  putStrLn "invariant property:"
  quickCheck (prop_invariantAlways popQBuggy)
  putStrLn ""

  putStrLn "=== the CORRECT implementation ==="
  putStr "single pop   : " >> quickCheck (prop_singlePopMatches popQ)
  putStr "sequence     : " >> quickCheck (prop_sequenceMatches popQ)
  putStr "invariant    : " >> quickCheck (prop_invariantAlways popQ)
  putStrLn ""

  putStrLn "--- command distribution ---"
  quickCheck prop_commandCoverage
  putStrLn ""

  putStrLn "--- the bug, by hand ---"
  putStrLn ("  " ++ trace popQBuggy [Push 1, Push 2, Pop, Pop])

-- なぜ「列」が必要なのか:
--
--   バグのある popQBuggy は、1回呼ぶだけなら正しい値を返します。
--   壊れるのは「内部状態」で、front が空なのに back が残る形になります。
--   toListQ (front ++ reverse back) は、その状態でも正しい内容を返すので、
--   1回の呼び出しをモデルと比べても違いが出ません。
--
--   ところが次に pop を呼ぶと、front が空なので Nothing を返してしまいます。
--   「Pop を2回続ける」列でしか出ないバグです。
--
-- state machine テストの構成要素 (どのライブラリでも同じです):
--
--   1. Cmd          操作を表すデータ型
--   2. Model        単純で正しい状態表現
--   3. stepModel    モデル上でコマンドを実行する
--   4. stepImpl     実装上でコマンドを実行する
--   5. Obs          外から観測できる値
--   6. プロパティ    コマンド列を両方に流し、観測列を比較する
--   7. shrink       コマンド列を短くする (shrinkList が自動でやってくれる)
--
-- ★ 7 が重要です。
--   反例が「30個のコマンド列」で報告されても読めません。
--   [Cmd] の shrink が効くので、上の実行結果では
--   [Push 0, Pop, Pop] のような最小の列まで縮みます。
--   Cmd の shrink を書いておくと、Push の引数も 0 まで縮みます。
--
-- 発展:
--   * 前提条件つきのコマンド (空のときは Pop を生成しない) を作ると、
--     より深い状態に到達しやすくなります
--   * 複数のプロセスで並行に実行し、線形化可能性を検査するのが
--     「並行 state machine テスト」です (Example 89)
--   * quickcheck-state-machine や quickcheck-dynamic といった
--     ライブラリは、この骨組みを汎用化したものです
