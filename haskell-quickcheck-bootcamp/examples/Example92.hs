-- Example 92: Ch8 総合演習「LRU キャッシュを state machine テストで固める」
--
-- IO・可変状態・コマンド列・モデル比較・カバレッジを全部使います。
-- 実務で state machine テストを書くときの、ほぼ完全なひな形です。
--
-- 実行: runghc Example92.hs
module Main (main) where

import Data.IORef
import Data.List (intercalate)
import Test.QuickCheck
import Test.QuickCheck.Monadic

------------------------------------------------------------
-- 実装: IORef で持つ LRU キャッシュ
------------------------------------------------------------
-- 内部表現: (容量, 新しい順に並べた [(キー, 値)])
data LRU = LRU Int (IORef [(Int, String)])

newLRU :: Int -> IO LRU
newLRU cap = LRU cap <$> newIORef []

lruGet :: LRU -> Int -> IO (Maybe String)
lruGet (LRU _ ref) k = do
  kvs <- readIORef ref
  case lookup k kvs of
    Nothing -> pure Nothing
    Just v  -> do
      -- ヒットしたら先頭に移動する (最近使ったものが先頭)
      writeIORef ref ((k, v) : filter ((/= k) . fst) kvs)
      pure (Just v)

lruPut :: LRU -> Int -> String -> IO ()
lruPut (LRU cap ref) k v = do
  kvs <- readIORef ref
  let kvs' = (k, v) : filter ((/= k) . fst) kvs
  writeIORef ref (take cap kvs')

lruSize :: LRU -> IO Int
lruSize (LRU _ ref) = length <$> readIORef ref

lruKeys :: LRU -> IO [Int]
lruKeys (LRU _ ref) = map fst <$> readIORef ref

------------------------------------------------------------
-- バグ入り実装: get でヒットしても順序を更新しない
--   (つまり LRU ではなく FIFO になっている)
------------------------------------------------------------
lruGetBuggy :: LRU -> Int -> IO (Maybe String)
lruGetBuggy (LRU _ ref) k = lookup k <$> readIORef ref

------------------------------------------------------------
-- モデル: 純粋なリスト (新しい順)
------------------------------------------------------------
type Model = [(Int, String)]

modelGet :: Int -> Model -> (Maybe String, Model)
modelGet k m = case lookup k m of
  Nothing -> (Nothing, m)
  Just v  -> (Just v, (k, v) : filter ((/= k) . fst) m)

modelPut :: Int -> Int -> String -> Model -> Model
modelPut cap k v m = take cap ((k, v) : filter ((/= k) . fst) m)

------------------------------------------------------------
-- コマンド
------------------------------------------------------------
data Cmd
  = Get Int
  | Put Int String
  | Size
  | Keys
  deriving (Eq)

instance Show Cmd where
  show (Get k)   = "Get " ++ show k
  show (Put k v) = "Put " ++ show k ++ " " ++ show v
  show Size      = "Size"
  show Keys      = "Keys"

-- キーの範囲を狭くするのが肝心です (Example 78 の技法6)。
-- 広い範囲だと、同じキーへの再アクセスが起きず、LRU の本質が試せません。
instance Arbitrary Cmd where
  arbitrary = frequency
    [ (4, Get <$> choose (0, 5))
    , (4, Put <$> choose (0, 5) <*> elements ["a", "b", "c"])
    , (1, pure Size)
    , (1, pure Keys)
    ]
  shrink (Get k)   = [ Get k' | k' <- shrink k, k' >= 0 ]
  shrink (Put k v) = Get k : [ Put k' v | k' <- shrink k, k' >= 0 ]
  shrink _         = []

------------------------------------------------------------
-- 観測
------------------------------------------------------------
data Obs
  = OGot (Maybe String)
  | OUnit
  | OSize Int
  | OKeys [Int]
  deriving (Eq, Show)

------------------------------------------------------------
-- 実行
------------------------------------------------------------
stepImpl :: (LRU -> Int -> IO (Maybe String)) -> LRU -> Cmd -> IO Obs
stepImpl getf lru cmd = case cmd of
  Get k   -> OGot <$> getf lru k
  Put k v -> lruPut lru k v >> pure OUnit
  Size    -> OSize <$> lruSize lru
  Keys    -> OKeys <$> lruKeys lru

stepModel :: Int -> Model -> Cmd -> (Obs, Model)
stepModel cap m cmd = case cmd of
  Get k   -> let (r, m') = modelGet k m in (OGot r, m')
  Put k v -> (OUnit, modelPut cap k v m)
  Size    -> (OSize (length m), m)
  Keys    -> (OKeys (map fst m), m)

runImpl :: (LRU -> Int -> IO (Maybe String)) -> Int -> [Cmd] -> IO [Obs]
runImpl getf cap cmds = do
  lru <- newLRU cap
  mapM (stepImpl getf lru) cmds

runModel :: Int -> [Cmd] -> [Obs]
runModel cap = go []
  where
    go _ []       = []
    go m (c : cs) = let (o, m') = stepModel cap m c in o : go m' cs

------------------------------------------------------------
-- トレース表示
------------------------------------------------------------
traceOf :: Int -> [Cmd] -> [Obs] -> String
traceOf cap cmds impl =
  intercalate "\n"
    [ "    " ++ pad 14 (show c)
        ++ " impl=" ++ pad 22 (show oi)
        ++ " model=" ++ pad 22 (show om)
        ++ (if oi == om then "" else "  <-- MISMATCH")
    | (c, oi, om) <- zip3 cmds impl (runModel cap cmds)
    ]
  where pad n s = s ++ replicate (n - length s) ' '

------------------------------------------------------------
-- プロパティ
------------------------------------------------------------
-- 注1: mapM は Traversable 上で多相なので、cmds の型注釈がないと
--      「Ambiguous type variable」でコンパイルが通りません。
--      forAllShrink (arbitrary :: Gen [Cmd]) と明示します。
--
-- 注2: forAll ではなく forAllShrink を使っています (Example 44)。
--      forAll のままだと、16 個のコマンド列がそのまま反例として出てきて読めません。
--      forAllShrink にすると 2〜4 個まで縮みます。
--      state machine テストでは、ここが決定的に効きます。
prop_matchesModel :: (LRU -> Int -> IO (Maybe String)) -> Property
prop_matchesModel getf =
  forAllShrink (choose (1, 4)) shrink $ \cap ->
  forAllShrink (arbitrary :: Gen [Cmd]) shrink $ \cmds -> monadicIO $ do
    obs <- run (runImpl getf cap cmds)
    monitor (counterexample ("capacity = " ++ show cap))
    monitor (counterexample (traceOf cap cmds obs))
    assert (obs == runModel cap cmds)

-- 容量を超えないこと (実装単体の不変条件)
prop_neverExceedsCapacity :: Property
prop_neverExceedsCapacity =
  forAllShrink (choose (1, 4)) shrink $ \cap ->
  forAllShrink (arbitrary :: Gen [Cmd]) shrink $ \cmds -> monadicIO $ do
    lru <- run (newLRU cap)
    sizes <- run (mapM (\c -> stepImpl lruGet lru c >> lruSize lru) cmds)
    monitor (counterexample (show (cap, cmds, sizes)))
    assert (all (<= cap) sizes)

-- キーの重複がないこと
prop_keysAreUnique :: Property
prop_keysAreUnique =
  forAllShrink (choose (1, 4)) shrink $ \cap ->
  forAllShrink (arbitrary :: Gen [Cmd]) shrink $ \cmds -> monadicIO $ do
    lru <- run (newLRU cap)
    _ <- run (mapM (stepImpl lruGet lru) cmds)
    ks <- run (lruKeys lru)
    monitor (counterexample (show ks))
    assert (length ks == length (dedup ks))
  where dedup = foldr (\x acc -> if x `elem` acc then acc else x : acc) []

-- Put したばかりのキーは、容量が 1 以上なら必ず取れる
prop_putThenGet :: Property
prop_putThenGet =
  forAll (choose (1, 4)) $ \cap ->
  forAll (choose (0, 5)) $ \k ->
  forAll (elements ["a", "b", "c"]) $ \v -> monadicIO $ do
    lru <- run (newLRU cap)
    run (lruPut lru k v)
    got <- run (lruGet lru k)
    assert (got == Just v)

-- コマンド列の分布を確認する (Ch7)
prop_coverage :: Property
prop_coverage =
  checkCoverage $
  forAll (choose (1, 4)) $ \cap ->
  forAll (arbitrary :: Gen [Cmd]) $ \cmds ->
    cover 40 (length cmds >= 4)        "4 or more commands"  $
    cover 20 (hasEviction cap cmds)    "an eviction happens" $
    cover 20 (hasGetHit cmds)          "a Get hits"          $
      True
  where
    hasEviction cap cmds = length [ () | Put _ _ <- cmds ] > cap
    hasGetHit cmds = go [] cmds
      where
        go _    []             = False
        go seen (Put k _ : cs) = go (k : seen) cs
        go seen (Get k : cs)   = k `elem` seen || go seen cs
        go seen (_ : cs)       = go seen cs

main :: IO ()
main = do
  putStrLn "--- sample command sequences ---"
  cs <- sample' (arbitrary :: Gen [Cmd])
  mapM_ (putStrLn . ("  " ++) . show) (take 4 cs)
  putStrLn ""

  putStrLn "=== correct implementation ==="
  putStr "matches model      : " >> quickCheckWith stdArgs { maxSuccess = 500 } (prop_matchesModel lruGet)
  putStr "capacity respected : " >> quickCheck prop_neverExceedsCapacity
  putStr "keys unique        : " >> quickCheck prop_keysAreUnique
  putStr "put then get       : " >> quickCheck prop_putThenGet
  putStrLn ""

  putStrLn "=== buggy implementation (Get does not refresh the order) ==="
  quickCheckWith stdArgs { maxSuccess = 500 } (prop_matchesModel lruGetBuggy)
  putStrLn ""

  putStrLn "--- command distribution ---"
  quickCheck prop_coverage
  putStrLn ""

  putStrLn "--- the bug, by hand (capacity 2) ---"
  lru <- newLRU 2
  _ <- lruPut lru 1 "one"
  _ <- lruPut lru 2 "two"
  hit <- lruGetBuggy lru 1        -- 1 を使ったので、本来は 1 が最新になるはず
  _ <- lruPut lru 3 "three"       -- 容量 2 なので何かが追い出される
  ks <- lruKeys lru
  putStrLn ("  get 1 -> " ++ show hit)
  putStrLn ("  keys after put 3 -> " ++ show ks)
  putStrLn "  with a correct LRU, key 1 survives and key 2 is evicted."

-- Ch8 のまとめ:
--
--   IO を含むプロパティ
--     ioProperty   単発の IO
--     monadicIO    手続き的に書きたいとき (run / assert / pre / monitor / pick)
--
--   例外
--     try (evaluate e)  純粋な式
--     try action        IO
--     total             落ちないことだけ確かめる
--
--   時間
--     within  タイムアウト
--
--   再現
--     replay = Just (mkQCGen seed, size)
--
--   ステートフルなコードのテスト (state machine テスト)
--     1. Cmd 型を定義する
--     2. Model (単純で正しい状態) を定義する
--     3. stepImpl / stepModel を書く
--     4. コマンド列を生成して両方に流し、観測列を比較する
--     5. トレースを counterexample で出す (これがないとデバッグできない)
--     6. コマンドの分布を cover で守る
--
--   ★ 5 と 6 を省略しないでください。
--     5 がないと、反例を見ても何が起きたか分かりません。
--     さらに forAllShrink を使わないと、コマンド列が縮まず、
--     長すぎるトレースになって結局読めません。
--     6 がないと、キーの範囲が広すぎて「ヒットが一度も起きない」
--     といった事態に気づけません。
