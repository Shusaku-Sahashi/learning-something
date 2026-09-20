-- Example 37: 実例「JSON の生成器と往復テスト」
--
-- Ch4 の技を総動員して、実用的な生成器を書きます。
--
-- 実行: runghc Example37.hs
module Main (main) where

import Data.Char (isDigit, isSpace)
import Data.List (intercalate)
import Test.QuickCheck

------------------------------------------------------------
-- JSON のデータ型
------------------------------------------------------------
data JSON
  = JNull
  | JBool Bool
  | JNum Int                 -- 簡単のため整数だけにします
  | JStr String
  | JArr [JSON]
  | JObj [(String, JSON)]
  deriving (Show, Eq)

------------------------------------------------------------
-- 生成器
------------------------------------------------------------
-- キーと文字列は、エスケープの要らない文字だけにします
-- (エスケープ込みにすると renderer/parser がぐっと複雑になるため)
genSafeString :: Gen String
genSafeString = listOf (elements (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ " -_"))

genKey :: Gen String
genKey = listOf1 (elements (['a' .. 'z'] ++ ['0' .. '9'] ++ "_"))

instance Arbitrary JSON where
  arbitrary = sized go
    where
      -- 終端 (スカラー値) だけを返す
      leaf = frequency
        [ (1, pure JNull)
        , (2, JBool <$> arbitrary)
        , (3, JNum <$> choose (-10000, 10000))
        , (3, JStr <$> genSafeString)
        ]
      go 0 = leaf
      go n = frequency
        [ (5, leaf)
        , (2, do k <- choose (0, 4)
                 JArr <$> vectorOf k (go (n `div` (k + 1))))
        , (2, do k <- choose (0, 4)
                 JObj <$> vectorOf k ((,) <$> genKey <*> go (n `div` (k + 1))))
        ]

------------------------------------------------------------
-- レンダラ (JSON -> String)
------------------------------------------------------------
render :: JSON -> String
render JNull      = "null"
render (JBool b)  = if b then "true" else "false"
render (JNum n)   = show n
render (JStr s)   = "\"" ++ s ++ "\""
render (JArr xs)  = "[" ++ intercalate "," (map render xs) ++ "]"
render (JObj kvs) = "{" ++ intercalate "," (map one kvs) ++ "}"
  where one (k, v) = "\"" ++ k ++ "\":" ++ render v

------------------------------------------------------------
-- パーサ (String -> Maybe JSON)
------------------------------------------------------------
-- 簡易の再帰下降パーサです。
parse :: String -> Maybe JSON
parse s = case pValue (dropWhile isSpace s) of
  Just (v, rest) | all isSpace rest -> Just v
  _                                 -> Nothing

pValue :: String -> Maybe (JSON, String)
pValue s = case s of
  ('n':'u':'l':'l':r)         -> Just (JNull, r)
  ('t':'r':'u':'e':r)         -> Just (JBool True, r)
  ('f':'a':'l':'s':'e':r)     -> Just (JBool False, r)
  ('"':r)                     -> pString r
  ('[':r)                     -> pArray (skip r)
  ('{':r)                     -> pObject (skip r)
  _                           -> pNumber s

skip :: String -> String
skip = dropWhile isSpace

pString :: String -> Maybe (JSON, String)
pString r = let (body, rest) = span (/= '"') r
            in case rest of
                 ('"':r') -> Just (JStr body, r')
                 _        -> Nothing

pKey :: String -> Maybe (String, String)
pKey ('"':r) = let (body, rest) = span (/= '"') r
               in case rest of
                    ('"':r') -> Just (body, r')
                    _        -> Nothing
pKey _ = Nothing

pNumber :: String -> Maybe (JSON, String)
pNumber s =
  let (sign, s1) = case s of
                     ('-':r) -> ("-", r)
                     _       -> ("", s)
      (ds, rest) = span isDigit s1
  in if null ds then Nothing else Just (JNum (read (sign ++ ds)), rest)

pArray :: String -> Maybe (JSON, String)
pArray (']':r) = Just (JArr [], r)
pArray s = go s []
  where
    go t acc = do
      (v, t1) <- pValue (skip t)
      case skip t1 of
        (',':t2) -> go t2 (v : acc)
        (']':t2) -> Just (JArr (reverse (v : acc)), t2)
        _        -> Nothing

pObject :: String -> Maybe (JSON, String)
pObject ('}':r) = Just (JObj [], r)
pObject s = go s []
  where
    go t acc = do
      (k, t1) <- pKey (skip t)
      case skip t1 of
        (':':t2) -> do
          (v, t3) <- pValue (skip t2)
          case skip t3 of
            (',':t4) -> go t4 ((k, v) : acc)
            ('}':t4) -> Just (JObj (reverse ((k, v) : acc)), t4)
            _        -> Nothing
        _ -> Nothing

------------------------------------------------------------
-- プロパティ
------------------------------------------------------------
-- 本命: 書き出して読み戻すと元に戻る
prop_roundTrip :: JSON -> Property
prop_roundTrip j = parse (render j) === Just j

-- パーサは何を渡しても落ちない
-- 注: total には NFData インスタンスが必要です。JSON には付けていないので、
--     render を挟んで Maybe String に変換してから評価しています。
--     render は構造全体をたどるので、これで JSON 全体が強制されます。
prop_parseTotal :: String -> Property
prop_parseTotal s = total (fmap render (parse s))

-- レンダリング結果は空にならない
prop_renderNonEmpty :: JSON -> Bool
prop_renderNonEmpty j = not (null (render j))

-- 配列の長さは保存される
prop_arrayLength :: [JSON] -> Property
prop_arrayLength xs = case parse (render (JArr xs)) of
  Just (JArr ys) -> length ys === length xs
  other          -> counterexample ("unexpected: " ++ show other) False

main :: IO ()
main = do
  putStrLn "--- sample JSON values ---"
  js <- sample' (arbitrary :: Gen JSON)
  mapM_ (putStrLn . render) (take 8 js)

  putStrLn ""
  putStrLn "--- properties ---"
  putStr "round trip      : " >> quickCheckWith stdArgs { maxSuccess = 500 } prop_roundTrip
  putStr "parse is total  : " >> quickCheck prop_parseTotal
  putStr "render non-empty: " >> quickCheck prop_renderNonEmpty
  putStr "array length    : " >> quickCheck prop_arrayLength

  putStrLn ""
  putStrLn "--- a few concrete checks ---"
  mapM_ showRT
    [ JNull
    , JArr [JNum 1, JStr "hi", JBool False]
    , JObj [("a", JNum 1), ("b", JArr [JNull])]
    ]
  where
    showRT j = do
      let t = render j
      putStrLn ("  " ++ t ++ "  ->  " ++ show (parse t))

-- この例から学べること:
--   * 再帰的な生成器は sized で書く (Example 33-34)
--   * 「難しい部分 (エスケープ) は最初は生成しない」と決めてよい。
--     テストできる範囲から始めて、あとで広げる。
--   * 往復プロパティ1本で、パーサとレンダラの両方を同時に検査できる。
--
-- 演習:
--   genSafeString に '"' を含めてみてください。往復が壊れます。
--   render 側でエスケープし、parse 側でアンエスケープすれば直ります。
