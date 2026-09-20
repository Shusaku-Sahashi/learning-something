-- Example 58: Ch5 総合演習「shrink 付きのデータ型を仕上げる」
--
-- Ch5 で学んだことを全部使って、実用的な型を完成させます。
--
-- 実行: runghc Example58.hs
{-# LANGUAGE DeriveGeneric #-}
module Main (main) where

import Data.List (sort, nub)
import GHC.Generics (Generic)
import Test.QuickCheck

------------------------------------------------------------
-- 題材: 「ページング条件」
--   不変条件:
--     1 <= perPage <= 100
--     0 <= pageIndex
--     sortKeys は重複なし、かつ 3 個以下
------------------------------------------------------------
data Paging = Paging
  { perPage   :: Int
  , pageIndex :: Int
  , sortKeys  :: [String]
  }
  deriving (Show, Eq, Generic)

validPaging :: Paging -> Bool
validPaging p =
  perPage p >= 1 && perPage p <= 100
    && pageIndex p >= 0
    && length (sortKeys p) <= 3
    && length (nub (sortKeys p)) == length (sortKeys p)

-- スマートコンストラクタ: どんな値からでも有効な Paging を作る
mkPaging :: Int -> Int -> [String] -> Paging
mkPaging pp pi_ ks = Paging
  { perPage   = max 1 (min 100 pp)
  , pageIndex = max 0 pi_
  , sortKeys  = take 3 (nub ks)
  }

availableKeys :: [String]
availableKeys = ["id", "name", "createdAt", "updatedAt", "score"]

instance Arbitrary Paging where
  arbitrary = mkPaging
    <$> choose (1, 100)
    <*> choose (0, 10000)
    <*> (take 3 . nub <$> listOf (elements availableKeys))

  -- 縮小の3原則:
  --   (a) 候補をスマートコンストラクタで直す
  --   (b) 直した結果が元と同じものは除く (無限ループ防止)
  --   (c) 大きく縮む候補を先に置く
  shrink p =
    [ q
    | q <- [ mkPaging pp pi_ ks
           | (pp, pi_, ks) <- shrink (perPage p, pageIndex p, sortKeys p)
           ]
    , q /= p
    ]

------------------------------------------------------------
-- テスト対象
------------------------------------------------------------
-- 「このページに含まれる要素」を切り出す (バグあり)
sliceBuggy :: Paging -> [a] -> [a]
sliceBuggy p xs = take (perPage p) (drop (pageIndex p * perPage p + 1) xs)
--                                                                ^^^ off-by-one
-- 補足: 最初は  - 1  と書いていましたが、Haskell の drop は負の数を 0 として
--       扱うため、pageIndex = 0 のページではバグが表に出ませんでした。
--       「バグを仕込んだのに落ちない」ときは、その入力でバグが発現するか
--       手で確かめてください (Example 22 の STEP 4 と同じ話です)。

slice :: Paging -> [a] -> [a]
slice p xs = take (perPage p) (drop (pageIndex p * perPage p) xs)

-- 全ページを集めると元に戻る
allPages :: Paging -> [a] -> [[a]]
allPages p xs =
  [ slice p { pageIndex = i } xs
  | i <- [0 .. (length xs + perPage p - 1) `div` perPage p - 1]
  ]

------------------------------------------------------------
-- 生成器と縮小のプロパティ (これを最初に書く)
------------------------------------------------------------
prop_genValid :: Paging -> Bool
prop_genValid = validPaging

prop_shrinkValid :: Paging -> Property
prop_shrinkValid p =
  counterexample (show (take 3 (shrink p))) (all validPaging (shrink p))

prop_shrinkNoSelf :: Paging -> Bool
prop_shrinkNoSelf p = p `notElem` shrink p

------------------------------------------------------------
-- 対象のプロパティ
------------------------------------------------------------
prop_sliceLength :: Paging -> [Int] -> Property
prop_sliceLength p xs =
  counterexample (show (length (slice p xs)))
    (length (slice p xs) <= perPage p)

prop_sliceIsSublist :: Paging -> [Int] -> Bool
prop_sliceIsSublist p xs = all (`elem` xs) (slice p xs)

prop_firstPageIsTake :: Paging -> [Int] -> Property
prop_firstPageIsTake p xs =
  slice p { pageIndex = 0 } xs === take (perPage p) xs

prop_allPagesRoundTrip :: Paging -> [Int] -> Property
prop_allPagesRoundTrip p xs = concat (allPages p xs) === xs

-- バグ版でも同じ性質を確かめる (落ちるはず)
prop_buggyFirstPage :: Paging -> [Int] -> Property
prop_buggyFirstPage p xs =
  sliceBuggy p { pageIndex = 0 } xs === take (perPage p) xs

main :: IO ()
main = do
  putStrLn "--- sample values ---"
  ps <- sample' (arbitrary :: Gen Paging)
  mapM_ print (take 4 ps)
  putStrLn ""

  putStrLn "--- shrink candidates ---"
  let p0 = Paging 50 7 ["id", "name", "score"]
  mapM_ (putStrLn . ("  " ++) . show) (take 6 (shrink p0))
  putStrLn ""

  putStrLn "--- generator and shrink are well behaved ---"
  putStr "generator valid  : " >> quickCheck prop_genValid
  putStr "shrink valid     : " >> quickCheck prop_shrinkValid
  putStr "shrink no self   : " >> quickCheck prop_shrinkNoSelf
  putStrLn ""

  putStrLn "--- properties of slice ---"
  putStr "length <= perPage: " >> quickCheck prop_sliceLength
  putStr "is a sublist     : " >> quickCheck prop_sliceIsSublist
  putStr "page 0 = take    : " >> quickCheck prop_firstPageIsTake
  putStr "all pages = xs   : " >> quickCheck prop_allPagesRoundTrip
  putStrLn ""

  putStrLn "--- the buggy version (fails, with a small counterexample) ---"
  quickCheck prop_buggyFirstPage
  putStrLn ("  slice      (page 0, perPage 2) [1..5] = "
              ++ show (slice (mkPaging 2 0 []) [1 .. 5 :: Int]))
  putStrLn ("  sliceBuggy (page 0, perPage 2) [1..5] = "
              ++ show (sliceBuggy (mkPaging 2 0 []) [1 .. 5 :: Int]))

-- Ch5 のまとめ:
--
--   1. Arbitrary を書いたら shrink も書く
--   2. 不変条件がある型は、縮小候補をスマートコンストラクタで直す
--   3. 直した結果が元と同じものは除く (無限ループ防止)
--   4. 次の3つのプロパティを必ず書く
--        prop_genValid      : 生成器が不変条件を守る
--        prop_shrinkValid   : 縮小が不変条件を守る
--        prop_shrinkNoSelf  : 縮小が自分自身を返さない
--   5. 不変条件がないなら genericShrink でよい
--   6. 縮小が効かないときは verboseShrinking で調べる
--
-- この6点を守れば、shrink でハマることはほぼなくなります。
