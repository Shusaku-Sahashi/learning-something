-- Example 80: Ch7 総合演習「API ハンドラの入力分布を設計する」
--
-- 実際の Web API を想定して、入力の分布を設計し、
-- カバレッジで守るところまでやります。
--
-- 実行: runghc Example80.hs
module Main (main) where

import Data.Char (isDigit)
import Test.QuickCheck

------------------------------------------------------------
-- 対象: 検索 API のハンドラ
------------------------------------------------------------
data Query = Query
  { qText   :: String
  , qPage   :: Int
  , qLimit  :: Int
  , qSort   :: Maybe String
  }
  deriving (Show, Eq)

data Response
  = BadRequest String
  | Empty
  | Page { resultCount :: Int, hasNext :: Bool }
  deriving (Show, Eq)

totalMatches :: String -> Int
totalMatches t
  | null t            = 0
  | all isDigit t     = 1
  | length t <= 2     = 500
  | otherwise         = max 0 (200 - 3 * length t)

handle :: Query -> Response
handle q
  | qLimit q < 1 || qLimit q > 100     = BadRequest "limit out of range"
  | qPage q < 0                        = BadRequest "page must be >= 0"
  | maybe False (`notElem` sortKeys) (qSort q) = BadRequest "unknown sort key"
  | total == 0                         = Empty
  | offset >= total                    = Empty
  | otherwise                          = Page shown (offset + shown < total)
  where
    sortKeys = ["relevance", "date", "score"]
    total    = totalMatches (qText q)
    offset   = qPage q * qLimit q
    shown    = min (qLimit q) (total - offset)

------------------------------------------------------------
-- STEP 1: 素朴な生成器を書く
------------------------------------------------------------
newtype NaiveQuery = NaiveQuery Query
  deriving (Show)

instance Arbitrary NaiveQuery where
  arbitrary = NaiveQuery <$> (Query <$> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary)

------------------------------------------------------------
-- STEP 2: 分布を測る
------------------------------------------------------------
responseName :: Response -> String
responseName (BadRequest _) = "BadRequest"
responseName Empty          = "Empty"
responseName Page {}        = "Page"

prop_measureNaive :: NaiveQuery -> Property
prop_measureNaive (NaiveQuery q) =
  tabulate "response" [responseName (handle q)] $
    total (show (handle q))

------------------------------------------------------------
-- STEP 3: 分布を設計した生成器を書く
------------------------------------------------------------
-- 設計方針:
--   * BadRequest は 3 種類あるので、それぞれ出るようにする
--   * Empty と Page もきちんと出るようにする
--   * 「最後のページ」(hasNext = False) を確実に出す
newtype DesignedQuery = DesignedQuery Query
  deriving (Show)

genText :: Gen String
genText = frequency
  [ (1, pure "")                                            -- total = 0
  , (2, vectorOf 3 (elements ['0' .. '9']))                 -- total = 1
  , (3, vectorOf 2 (elements ['a' .. 'z']))                 -- total = 500
  , (4, do n <- choose (3, 70)
           vectorOf n (elements ['a' .. 'z']))              -- total = 200 - 3n
  ]

genLimit :: Gen Int
genLimit = frequency
  [ (7, choose (1, 100))                                    -- 正常
  , (2, elements [1, 100])                                  -- 境界ぴったり
  , (1, oneof [choose (-10, 0), choose (101, 200)])         -- 範囲外
  ]

genPage :: Gen Int
genPage = frequency
  [ (6, choose (0, 5))
  , (2, pure 0)
  , (1, choose (6, 100))                                    -- 行き過ぎたページ
  , (1, choose (-5, -1))                                    -- 不正
  ]

genSort :: Gen (Maybe String)
genSort = frequency
  [ (4, pure Nothing)
  , (4, Just <$> elements ["relevance", "date", "score"])
  , (1, Just <$> elements ["name", "", "RELEVANCE"])        -- 不正なキー
  ]

instance Arbitrary DesignedQuery where
  arbitrary = DesignedQuery <$> (Query <$> genText <*> genPage <*> genLimit <*> genSort)
  shrink (DesignedQuery q) =
    [ DesignedQuery q { qText = t } | t <- shrinkList (const []) (qText q) ]

prop_measureDesigned :: DesignedQuery -> Property
prop_measureDesigned (DesignedQuery q) =
  tabulate "response" [responseName (handle q)] $
    total (show (handle q))

------------------------------------------------------------
-- STEP 4: カバレッジで固定する
------------------------------------------------------------
prop_coverage :: Property
prop_coverage =
  checkCoverage $
  forAll (arbitrary :: Gen DesignedQuery) $ \(DesignedQuery q) ->
    let r = handle q in
    tabulate "response" [responseName r] $
    coverTable "response" [ ("BadRequest", 15), ("Empty", 5), ("Page", 25) ] $
    cover 5 (isLastPage r) "last page (hasNext = False)" $
    cover 3 (isFirstOfMany q r) "first page of many" $
      total (show r)
  where
    isLastPage (Page _ False) = True
    isLastPage _              = False
    isFirstOfMany q (Page _ True) = qPage q == 0
    isFirstOfMany _ _             = False

------------------------------------------------------------
-- STEP 5: 本来のプロパティを書く
------------------------------------------------------------
prop_resultCountWithinLimit :: DesignedQuery -> Property
prop_resultCountWithinLimit (DesignedQuery q) =
  case handle q of
    Page n _ -> counterexample (show (n, qLimit q)) (n <= qLimit q && n > 0)
    _        -> property True

prop_badRequestHasReason :: DesignedQuery -> Property
prop_badRequestHasReason (DesignedQuery q) =
  case handle q of
    BadRequest msg -> counterexample msg (not (null msg))
    _              -> property True

-- ★ Ch6 の教訓をここでも適用します。
--   最初は次のように書いていました。
--
--     prop_emptyTextGivesEmpty (DesignedQuery q) =
--       qLimit q >= 1 && qLimit q <= 100 && qPage q >= 0 && validSort (qSort q)
--         ==> null (qText q) ==> handle q === Empty
--
--   条件が4つ重なったうえに「テキストが空」まで要求するので、
--   Gave up しました (実測: 1000 捨てて 81 件しか通らない)。
--   条件を検査するのをやめて、条件を満たすクエリを直接作ります。
prop_emptyTextGivesEmpty :: Property
prop_emptyTextGivesEmpty =
  forAll genValidParams $ \(lim, pg, srt) ->
    handle (Query "" pg lim srt) === Empty
  where
    genValidParams = (,,)
      <$> choose (1, 100)
      <*> choose (0, 100)
      <*> elements [Nothing, Just "relevance", Just "date", Just "score"]

prop_pagingCoversAll :: Property
prop_pagingCoversAll =
  forAll genText $ \t ->
    forAll (choose (1, 100)) $ \lim ->
      let tot   = totalMatches t
          pages = [ handle (Query t p lim Nothing) | p <- [0 .. 20] ]
          shown = sum [ n | Page n _ <- pages ]
      in counterexample (show (tot, lim, shown))
           (shown == min tot (21 * lim))

main :: IO ()
main = do
  putStrLn "--- STEP 2: what does the naive generator produce? ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_measureNaive
  putStrLn "  ^ almost everything is BadRequest. The real logic is never reached."
  putStrLn ""

  putStrLn "--- STEP 3: the designed generator ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_measureDesigned
  putStrLn ""

  putStrLn "--- STEP 4: coverage is now guaranteed ---"
  quickCheck prop_coverage
  putStrLn ""

  putStrLn "--- STEP 5: the actual properties ---"
  putStr "count within limit   : " >> quickCheck prop_resultCountWithinLimit
  putStr "bad request has msg  : " >> quickCheck prop_badRequestHasReason
  putStr "empty text -> Empty  : " >> quickCheck prop_emptyTextGivesEmpty
  putStr "paging covers all    : " >> quickCheck prop_pagingCoversAll

-- Ch7 のまとめ:
--
--   測る道具:
--     collect   値の分布
--     label     排他的なカテゴリ
--     classify  条件を満たした割合
--     tabulate  名前付きの表 (1件から複数記録できる)
--
--   守る道具:
--     cover          ラベルごとの下限 (既定では警告のみ)
--     coverTable     表全体の下限
--     checkCoverage  下限を満たさなければ失敗させる
--
--   手順:
--     1. 素朴な生成器で書く
--     2. tabulate / classify で分布を測る
--     3. 届いていない分岐を見つける
--     4. 生成器を設計し直す (Example 78 の技法カタログ)
--     5. cover + checkCoverage で固定する
--     6. そこで初めて、本来のプロパティを書く
--
--   STEP 2 を飛ばすと、「通っているのに何も検査していないテスト」が
--   静かに積み上がっていきます。必ず測ってください。
