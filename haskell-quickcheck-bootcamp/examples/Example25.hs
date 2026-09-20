-- Example 25: 自分で Gen を作る (2) oneof と frequency
--
-- 「いくつかの作り方のどれかを選ぶ」ための部品です。
--
-- 実行: runghc Example25.hs
module Main (main) where

import Test.QuickCheck

-- oneof :: [Gen a] -> Gen a
--   複数の生成器から等確率で1つ選んで使う。
genSmallOrBig :: Gen Int
genSmallOrBig = oneof
  [ choose (0, 9)
  , choose (1000000, 9999999)
  ]

-- frequency :: [(Int, Gen a)] -> Gen a
--   重み付きで選ぶ。重みの合計に対する比率で選ばれます。
--   重み 0 の要素は絶対に選ばれません。
genMostlySmall :: Gen Int
genMostlySmall = frequency
  [ (9, choose (0, 9))              -- 90%
  , (1, choose (1000000, 9999999))  -- 10%
  ]

-- 実務でよくある形: 「大半は正常系、たまに異常系」
data Request = Request
  { path   :: String
  , method :: String
  , body   :: Maybe String
  }
  deriving (Show)

genPath :: Gen String
genPath = frequency
  [ (7, elements ["/users", "/items", "/health"])   -- よくあるパス
  , (2, ("/users/" ++) . show <$> choose (1 :: Int, 1000))
  , (1, elements ["", "/", "//", "/../etc/passwd"]) -- 変な入力
  ]

genRequest :: Gen Request
genRequest = do
  p <- genPath
  m <- frequency [ (5, pure "GET"), (3, pure "POST"), (1, pure "DELETE"), (1, pure "TRACE") ]
  b <- if m == "POST"
         then Just <$> elements ["{}", "{\"a\":1}", ""]
         else frequency [ (9, pure Nothing), (1, Just <$> pure "unexpected") ]
  pure (Request p m b)

-- Maybe の生成を自分で書くとこうなります。
-- (標準の Arbitrary (Maybe a) もほぼ同じことをしています)
genMaybeInt :: Gen (Maybe Int)
genMaybeInt = frequency
  [ (1, pure Nothing)
  , (3, Just <$> arbitrary)
  ]

main :: IO ()
main = do
  putStrLn "--- oneof: small or big (50/50) ---"
  xs <- sample' genSmallOrBig
  print xs

  putStrLn "--- frequency: mostly small (90/10) ---"
  ys <- sample' genMostlySmall
  print ys

  putStrLn "--- frequency: Maybe Int ---"
  ms <- sample' genMaybeInt
  print ms

  putStrLn ""
  putStrLn "--- realistic: HTTP requests ---"
  rs <- sample' genRequest
  mapM_ print (take 8 rs)

  putStrLn ""
  putStrLn "--- how often is each branch taken? (200 draws) ---"
  draws <- sequence (replicate 200 (generate genMostlySmall))
  let small = length (filter (< 10) draws)
  putStrLn ("  small: " ++ show small ++ " / 200")
  putStrLn ("  big  : " ++ show (200 - small) ++ " / 200")

-- oneof [g1, g2, g3] は frequency [(1,g1),(1,g2),(1,g3)] と同じです。
--
-- 注意点:
--   oneof []      は実行時エラーです。
--   frequency []  も実行時エラーです。
--   重みが全部 0 でもエラーになります。
--
-- 設計の勘所:
--   「異常系に寄せすぎない」こと。
--   異常系ばかり生成すると、正常系の深いロジックに到達できません。
--   実際にどんな割合で生成されているかは、classify や tabulate で
--   測るのが確実です (Ch7)。
