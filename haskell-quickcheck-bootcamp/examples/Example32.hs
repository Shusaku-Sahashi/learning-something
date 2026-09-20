-- Example 32: レコード型と列挙型
--
-- 実務で一番よく生成するのは、たいていレコード型です。
--
-- 実行: runghc Example32.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- 列挙型: arbitraryBoundedEnum が使える
------------------------------------------------------------
data Role = Admin | Editor | Viewer
  deriving (Show, Eq, Ord, Enum, Bounded)

instance Arbitrary Role where
  -- Enum と Bounded を derive していれば1行で済みます。
  arbitrary = arbitraryBoundedEnum

data Status = Active | Suspended | Deleted
  deriving (Show, Eq, Enum, Bounded)

instance Arbitrary Status where
  -- 重みを変えたいときは frequency で書きます。
  -- 「実際のデータはほとんど Active」という状況を再現しています。
  arbitrary = frequency
    [ (8, pure Active)
    , (1, pure Suspended)
    , (1, pure Deleted)
    ]

------------------------------------------------------------
-- レコード型
------------------------------------------------------------
data User = User
  { userId    :: Int
  , userName  :: String
  , userRole  :: Role
  , userAge   :: Int
  , isEnabled :: Bool
  }
  deriving (Show, Eq)

instance Arbitrary User where
  arbitrary = User
    <$> choose (1, 1000000)                          -- userId
    <*> genName                                      -- userName
    <*> arbitrary                                    -- userRole
    <*> choose (0, 120)                              -- userAge
    <*> arbitrary                                    -- isEnabled

genName :: Gen String
genName = do
  n <- choose (1, 12)
  vectorOf n (elements (['a' .. 'z'] ++ ['A' .. 'Z']))

-- フィールドが増えると <*> を数えるのが辛くなります。
-- そういうときは do 記法にすると、どのフィールドか一目で分かります。
data Config = Config
  { host       :: String
  , port       :: Int
  , timeoutSec :: Int
  , retries    :: Int
  , isVerbose  :: Bool   -- 注: `verbose` という名前は Test.QuickCheck の関数と衝突します
  }
  deriving (Show, Eq)

instance Arbitrary Config where
  arbitrary = do
    host'       <- elements ["localhost", "127.0.0.1", "example.com"]
    port'       <- choose (1, 65535)
    timeoutSec' <- choose (1, 300)
    retries'    <- choose (0, 5)
    isVerbose'  <- arbitrary
    pure Config { host = host'
                , port = port'
                , timeoutSec = timeoutSec'
                , retries = retries'
                , isVerbose = isVerbose'
                }

------------------------------------------------------------
-- 生成した値でプロパティを書く
------------------------------------------------------------
canEdit :: User -> Bool
canEdit u = isEnabled u && userRole u /= Viewer

prop_viewerCannotEdit :: User -> Bool
prop_viewerCannotEdit u = userRole u /= Viewer || not (canEdit u)

prop_disabledCannotEdit :: User -> Bool
prop_disabledCannotEdit u = isEnabled u || not (canEdit u)

prop_configPortValid :: Config -> Bool
prop_configPortValid c = port c >= 1 && port c <= 65535

prop_userAgeValid :: User -> Bool
prop_userAgeValid u = userAge u >= 0 && userAge u <= 120

main :: IO ()
main = do
  putStrLn "--- Role (arbitraryBoundedEnum) ---"
  rs <- sample' (arbitrary :: Gen Role)
  print rs

  putStrLn "--- Status (weighted) ---"
  sts <- sequence (replicate 100 (generate (arbitrary :: Gen Status)))
  putStrLn ("  Active    : " ++ show (length (filter (== Active) sts)))
  putStrLn ("  Suspended : " ++ show (length (filter (== Suspended) sts)))
  putStrLn ("  Deleted   : " ++ show (length (filter (== Deleted) sts)))

  putStrLn "--- User ---"
  us <- sample' (arbitrary :: Gen User)
  mapM_ print (take 4 us)

  putStrLn "--- Config ---"
  cs <- sample' (arbitrary :: Gen Config)
  mapM_ print (take 3 cs)

  putStrLn ""
  putStrLn "--- properties ---"
  putStr "viewer cannot edit   : " >> quickCheck prop_viewerCannotEdit
  putStr "disabled cannot edit : " >> quickCheck prop_disabledCannotEdit
  putStr "port is valid        : " >> quickCheck prop_configPortValid
  putStr "age is valid         : " >> quickCheck prop_userAgeValid

-- レコード型の Arbitrary を書くときのコツ:
--   1. フィールドの意味に合った範囲を指定する
--      (userId に負の数を入れる意味がないなら choose (1, ...) にする)
--   2. 実際のデータ分布に近づける
--      (Status のほとんどが Active なら、生成もそうする)
--   3. ただし「ありえない値」も少しは混ぜる
--      (port = 1 や port = 65535 のような境界値)
--
-- 「型が許すすべての値」を一様に生成すると、
-- 現実には起きない入力ばかりでテスト時間を使ってしまうことがあります。
-- 逆に絞りすぎると、境界のバグを見逃します。バランスは Ch7 で測ります。
