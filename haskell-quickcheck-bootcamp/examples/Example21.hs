-- Example 21: ケーススタディ「連想リストの性質を洗い出す」
--
-- Ch2 で学んだパターンを1つの題材に総動員します。
-- 題材は「キーと値を持つ簡単な辞書」です。
--
-- パターンの復習:
--   往復 / 不変条件 / 冪等性 / 代数法則 / オラクル / メタモルフィック / 構造 / 全域性
--
-- 実行: runghc Example21.hs
module Main (main) where

import Data.List (nub, sort)
import qualified Data.Map.Strict as M
import Test.QuickCheck

------------------------------------------------------------
-- 実装: 連想リストによる辞書
------------------------------------------------------------
newtype Dict = Dict [(Int, String)]
  deriving (Show)

emptyD :: Dict
emptyD = Dict []

insertD :: Int -> String -> Dict -> Dict
insertD k v (Dict kvs) = Dict ((k, v) : filter ((/= k) . fst) kvs)

lookupD :: Int -> Dict -> Maybe String
lookupD k (Dict kvs) = lookup k kvs

deleteD :: Int -> Dict -> Dict
deleteD k (Dict kvs) = Dict (filter ((/= k) . fst) kvs)

keysD :: Dict -> [Int]
keysD (Dict kvs) = map fst kvs

sizeD :: Dict -> Int
sizeD (Dict kvs) = length kvs

fromListD :: [(Int, String)] -> Dict
fromListD = foldr (\(k, v) d -> insertD k v d) emptyD

toMapD :: Dict -> M.Map Int String
toMapD (Dict kvs) = M.fromList (reverse kvs)

instance Arbitrary Dict where
  arbitrary = fromListD <$> arbitrary

------------------------------------------------------------
-- (1) 往復: insert してから lookup すると取り出せる
------------------------------------------------------------
prop_insertLookup :: Int -> String -> Dict -> Property
prop_insertLookup k v d = lookupD k (insertD k v d) === Just v

------------------------------------------------------------
-- (2) 不変条件: キーは重複しない
------------------------------------------------------------
prop_keysUnique :: Dict -> Property
prop_keysUnique d = let ks = keysD d in length (nub ks) === length ks

-- 不変条件は「操作しても保たれる」ことが大事です。
prop_insertKeepsUnique :: Int -> String -> Dict -> Property
prop_insertKeepsUnique k v d =
  let ks = keysD (insertD k v d) in length (nub ks) === length ks

------------------------------------------------------------
-- (3) 冪等性: 同じ delete を2回しても変わらない
------------------------------------------------------------
prop_deleteIdempotent :: Int -> Dict -> Property
prop_deleteIdempotent k d =
  toMapD (deleteD k (deleteD k d)) === toMapD (deleteD k d)

-- 同じキーへの insert も、最後に書いた値だけが残る
prop_insertOverwrites :: Int -> String -> String -> Dict -> Property
prop_insertOverwrites k v1 v2 d =
  lookupD k (insertD k v2 (insertD k v1 d)) === Just v2

------------------------------------------------------------
-- (4) 交換関係: キーが違う insert は順番を入れ替えてもよい
------------------------------------------------------------
prop_insertCommutes :: Int -> String -> Int -> String -> Dict -> Property
prop_insertCommutes k1 v1 k2 v2 d =
  k1 /= k2 ==>
    toMapD (insertD k1 v1 (insertD k2 v2 d))
      === toMapD (insertD k2 v2 (insertD k1 v1 d))

------------------------------------------------------------
-- (5) オラクル: Data.Map と比べる
------------------------------------------------------------
prop_lookupMatchesMap :: Int -> Dict -> Property
prop_lookupMatchesMap k d = lookupD k d === M.lookup k (toMapD d)

prop_sizeMatchesMap :: Dict -> Property
prop_sizeMatchesMap d = sizeD d === M.size (toMapD d)

prop_keysMatchesMap :: Dict -> Property
prop_keysMatchesMap d = sort (keysD d) === M.keys (toMapD d)

------------------------------------------------------------
-- (6) 無関係なキーは影響を受けない (局所性)
------------------------------------------------------------
prop_insertOtherKey :: Int -> String -> Int -> Dict -> Property
prop_insertOtherKey k v k' d =
  k /= k' ==> lookupD k' (insertD k v d) === lookupD k' d

prop_deleteOtherKey :: Int -> Int -> Dict -> Property
prop_deleteOtherKey k k' d =
  k /= k' ==> lookupD k' (deleteD k d) === lookupD k' d

------------------------------------------------------------
-- (7) 削除後は必ず見つからない
------------------------------------------------------------
prop_deleteThenLookup :: Int -> Dict -> Property
prop_deleteThenLookup k d = lookupD k (deleteD k d) === Nothing

------------------------------------------------------------
-- (8) 全域性: どんな操作をしても落ちない
------------------------------------------------------------
prop_totalOps :: Int -> String -> Dict -> Property
prop_totalOps k v d =
  total (sizeD (insertD k v (deleteD k d)), keysD d, lookupD k d)

main :: IO ()
main = do
  putStrLn "--- round-trip ---"
  putStr "insert then lookup  : " >> quickCheck prop_insertLookup
  putStrLn "--- invariants ---"
  putStr "keys unique         : " >> quickCheck prop_keysUnique
  putStr "insert keeps unique : " >> quickCheck prop_insertKeepsUnique
  putStrLn "--- idempotence ---"
  putStr "delete twice        : " >> quickCheck prop_deleteIdempotent
  putStr "insert overwrites   : " >> quickCheck prop_insertOverwrites
  putStrLn "--- commutation ---"
  putStr "insert commutes     : " >> quickCheck prop_insertCommutes
  putStrLn "--- oracle (Data.Map) ---"
  putStr "lookup              : " >> quickCheck prop_lookupMatchesMap
  putStr "size                : " >> quickCheck prop_sizeMatchesMap
  putStr "keys                : " >> quickCheck prop_keysMatchesMap
  putStrLn "--- locality ---"
  putStr "insert other key    : " >> quickCheck prop_insertOtherKey
  putStr "delete other key    : " >> quickCheck prop_deleteOtherKey
  putStrLn "--- delete ---"
  putStr "delete then lookup  : " >> quickCheck prop_deleteThenLookup
  putStrLn "--- totality ---"
  putStr "no crashes          : " >> quickCheck prop_totalOps

-- 演習:
--   deleteD をわざと壊してみてください。例えば
--       deleteD k (Dict kvs) = Dict (drop 1 (filter ((/= k) . fst) kvs))
--   どのプロパティが落ちるか、予想してから実行してみましょう。
--
-- 注目してほしい点:
--   1つの小さなデータ型に対して、これだけの性質が書けます。
--   逆に言えば、テストしていない性質がこれだけあったということです。
