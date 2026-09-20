-- Example 39: 生成器を部品にして使い回す
--
-- プロジェクトが大きくなると、生成器の量も増えます。
-- 最初から「部品として書く」癖をつけると、あとが楽になります。
--
-- 実行: runghc Example39.hs
module Main (main) where

import Data.List (isInfixOf)
import Test.QuickCheck

------------------------------------------------------------
-- 汎用の部品 (プロジェクト共通の Gen モジュールに置くイメージ)
------------------------------------------------------------
-- 文字種を指定して文字列を作る
genStringOf :: String -> Int -> Int -> Gen String
genStringOf alphabet lo hi = do
  n <- choose (lo, hi)
  vectorOf n (elements alphabet)

alphaNum :: String
alphaNum = ['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9']

lower :: String
lower = ['a' .. 'z']

digits :: String
digits = ['0' .. '9']

-- 「たまに Nothing」
genMaybeOf :: Gen a -> Gen (Maybe a)
genMaybeOf g = frequency [ (1, pure Nothing), (4, Just <$> g) ]

-- 「ほとんどは正常、たまに異常」
genMostly :: Gen a -> Gen a -> Gen a
genMostly normal weird = frequency [ (9, normal), (1, weird) ]

-- 空でないリスト
genNonEmptyOf :: Gen a -> Gen [a]
genNonEmptyOf = listOf1

-- 重複のない n 要素を、候補リストから選ぶ
genDistinctFrom :: Int -> [a] -> Gen [a]
genDistinctFrom n xs = take n <$> shuffle xs

------------------------------------------------------------
-- ドメイン固有の部品 (これも使い回す)
------------------------------------------------------------
genUserId :: Gen Int
genUserId = choose (1, 999999)

genUserName :: Gen String
genUserName = genMostly
  (genStringOf alphaNum 3 16)
  (elements ["", " ", "a", replicate 200 'x', "admin", "root"])

genEmail :: Gen String
genEmail = do
  local  <- genStringOf lower 1 10
  domain <- genStringOf lower 2 8
  tld    <- elements ["com", "jp", "org", "dev"]
  pure (local ++ "@" ++ domain ++ "." ++ tld)

genPhone :: Gen String
genPhone = do
  a <- genStringOf digits 2 4
  b <- genStringOf digits 3 4
  c <- genStringOf digits 4 4
  pure (a ++ "-" ++ b ++ "-" ++ c)

------------------------------------------------------------
-- 部品を組み合わせて、アプリの型を作る
------------------------------------------------------------
data Account = Account
  { accId    :: Int
  , accName  :: String
  , accEmail :: String
  , accPhone :: Maybe String
  , accTags  :: [String]
  }
  deriving (Show, Eq)

instance Arbitrary Account where
  arbitrary = Account
    <$> genUserId
    <*> genUserName
    <*> genEmail
    <*> genMaybeOf genPhone
    <*> genDistinctFrom 3 ["vip", "beta", "internal", "trial", "legacy"]

------------------------------------------------------------
-- テスト対象と、そのプロパティ
------------------------------------------------------------
-- 「表示用の名前」を作る。20文字を超えたら切り詰める。
displayName :: Account -> String
displayName a
  | null (accName a)        = "user" ++ show (accId a)
  | length (accName a) > 20 = take 17 (accName a) ++ "..."
  | otherwise               = accName a

-- よくある書き間違い: 切り詰めた「あと」に "..." を足すぶんを数え忘れている。
-- take 20 の 20 文字 + "..." の 3 文字 = 23 文字になってしまいます。
displayNameBuggy :: Account -> String
displayNameBuggy a
  | null (accName a)        = "user" ++ show (accId a)
  | length (accName a) > 20 = take 20 (accName a) ++ "..."
  | otherwise               = accName a

prop_displayNameNonEmpty :: Account -> Bool
prop_displayNameNonEmpty a = not (null (displayName a))

prop_displayNameBounded :: Account -> Property
prop_displayNameBounded a =
  counterexample (show (displayName a))
    (length (displayName a) <= 20)

prop_displayNameBuggyBounded :: Account -> Property
prop_displayNameBuggyBounded a =
  counterexample (show (displayNameBuggy a))
    (length (displayNameBuggy a) <= 20)

prop_emailHasAt :: Account -> Bool
prop_emailHasAt a = '@' `elem` accEmail a

prop_tagsDistinct :: Account -> Bool
prop_tagsDistinct a = length (accTags a) == length (dedup (accTags a))
  where dedup = foldr (\x acc -> if x `elem` acc then acc else x : acc) []

prop_phoneFormat :: Account -> Property
prop_phoneFormat a = case accPhone a of
  Nothing -> property True
  Just p  -> counterexample p (property ("-" `isInfixOf` p))

main :: IO ()
main = do
  putStrLn "--- reusable pieces ---"
  a <- sample' (genStringOf lower 3 6)
  print a
  b <- sample' (genMaybeOf genPhone)
  print (take 6 b)
  c <- sample' (genDistinctFrom 3 ["vip", "beta", "internal", "trial", "legacy"])
  mapM_ print (take 5 c)

  putStrLn ""
  putStrLn "--- Account ---"
  accs <- sample' (arbitrary :: Gen Account)
  mapM_ print (take 5 accs)

  putStrLn ""
  putStrLn "--- properties ---"
  putStr "display name non-empty : " >> quickCheck prop_displayNameNonEmpty
  putStr "email has @            : " >> quickCheck prop_emailHasAt
  putStr "tags distinct          : " >> quickCheck prop_tagsDistinct
  putStr "phone format           : " >> quickCheck prop_phoneFormat
  putStr "display name <= 20     : " >> quickCheck prop_displayNameBounded
  putStrLn "buggy version (fails on purpose):"
  quickCheck prop_displayNameBuggyBounded

-- ここで効いているのは genUserName の異常系です。
--   genUserName は 9:1 の割合で「普通の名前」と「意地悪な名前」を作ります。
--   意地悪なほうに replicate 200 'x' が入っているので、
--   10回に1回くらいは 200 文字の名前が来ます。
--   だから buggy 版はすぐ (だいたい 10 件以内で) 反例が見つかります。
--
--   もし genUserName が「3〜16文字の普通の名前」しか作らなかったら、
--   切り詰めの分岐には一度も入らず、このバグは永遠に見つかりません。
--   生成器の質が、そのままテストの質になります。
--
-- 生成器を部品化する利点:
--   * 同じ「意地悪な名前」を全テストで使い回せる
--   * 「メールアドレスの形式を変えたい」とき1ヶ所で済む
--   * 生成器自体にプロパティを書いてテストできる (Example 30)
--
-- 実プロジェクトでは test/Gen/ 以下にモジュールを切って置くのが定番です。
