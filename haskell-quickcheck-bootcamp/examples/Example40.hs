-- Example 40: 無効な入力も生成する (negative testing)
--
-- ここまでは「正しい入力」を作ってきました。
-- しかし実務では「不正な入力を正しく拒否できるか」も同じくらい大事です。
--
-- 実行: runghc Example40.hs
module Main (main) where

import Data.Char (isDigit)
import Test.QuickCheck

------------------------------------------------------------
-- 題材: バリデーション付きのユーザ登録
------------------------------------------------------------
data Signup = Signup { suName :: String, suAge :: String, suMail :: String }
  deriving (Show, Eq)

data Err
  = EmptyName
  | NameTooLong
  | AgeNotNumeric
  | AgeOutOfRange
  | MailNoAt
  deriving (Show, Eq, Ord)

validate :: Signup -> Either [Err] (String, Int, String)
validate (Signup n a m) =
  case errs of
    [] -> Right (n, read a, m)
    _  -> Left errs
  where
    errs = concat
      [ [ EmptyName     | null n ]
      , [ NameTooLong   | length n > 32 ]
      , [ AgeNotNumeric | null a || not (all isDigit a) ]
      , [ AgeOutOfRange | all isDigit a && not (null a) && (read a :: Integer) > 150 ]
      , [ MailNoAt      | '@' `notElem` m ]
      ]

------------------------------------------------------------
-- 有効な入力の生成器
------------------------------------------------------------
genValidName :: Gen String
genValidName = do
  n <- choose (1, 32)
  vectorOf n (elements (['a' .. 'z'] ++ ['A' .. 'Z']))

genValidAge :: Gen String
genValidAge = show <$> choose (0 :: Int, 150)

genValidMail :: Gen String
genValidMail = do
  l <- listOf1 (elements ['a' .. 'z'])
  d <- listOf1 (elements ['a' .. 'z'])
  pure (l ++ "@" ++ d ++ ".com")

newtype ValidSignup = ValidSignup Signup deriving (Show)

instance Arbitrary ValidSignup where
  arbitrary = ValidSignup <$> (Signup <$> genValidName <*> genValidAge <*> genValidMail)

------------------------------------------------------------
-- 無効な入力の生成器: 「有効なものを1ヶ所だけ壊す」のが定石
------------------------------------------------------------
-- 壊し方を型で表すと、どの検査が効いているか分かります。
data Breakage = BreakName | BreakLongName | BreakAge | BreakAgeRange | BreakMail
  deriving (Show, Eq, Enum, Bounded)

expectedErr :: Breakage -> Err
expectedErr BreakName     = EmptyName
expectedErr BreakLongName = NameTooLong
expectedErr BreakAge      = AgeNotNumeric
expectedErr BreakAgeRange = AgeOutOfRange
expectedErr BreakMail     = MailNoAt

data InvalidSignup = InvalidSignup Breakage Signup
  deriving (Show)

instance Arbitrary InvalidSignup where
  arbitrary = do
    ValidSignup s <- arbitrary
    b <- arbitraryBoundedEnum
    s' <- case b of
      BreakName     -> pure s { suName = "" }
      BreakLongName -> do
        k <- choose (33, 60)
        pure s { suName = replicate k 'a' }
      BreakAge      -> do
        bad <- elements ["", "abc", "1a", "-5", " 12", "12 "]
        pure s { suAge = bad }
      BreakAgeRange -> do
        v <- choose (151 :: Int, 100000)
        pure s { suAge = show v }
      BreakMail     -> pure s { suMail = filter (/= '@') (suMail s) }
    pure (InvalidSignup b s')

------------------------------------------------------------
-- プロパティ
------------------------------------------------------------
-- 正常系: 有効な入力は必ず通る
prop_validAccepted :: ValidSignup -> Property
prop_validAccepted (ValidSignup s) =
  counterexample (show (validate s)) (isRight (validate s))
  where isRight (Right _) = True
        isRight _         = False

-- 異常系: 壊した入力は必ず弾かれる
prop_invalidRejected :: InvalidSignup -> Property
prop_invalidRejected (InvalidSignup _ s) =
  counterexample (show (validate s)) (isLeft (validate s))
  where isLeft (Left _) = True
        isLeft _        = False

-- 異常系: しかも「期待したエラー」が含まれている
-- これが大事です。「なんらかの理由で弾かれた」だけでは、
-- 検査ロジックが正しいとは言えません。
prop_invalidRightReason :: InvalidSignup -> Property
prop_invalidRightReason (InvalidSignup b s) =
  case validate s of
    Left errs -> counterexample (show (b, errs)) (expectedErr b `elem` errs)
    Right _   -> counterexample "accepted an invalid input" False

-- どんな入力でも落ちない
prop_neverCrashes :: Signup -> Property
prop_neverCrashes s = total (either show (\(n, a, m) -> n ++ show a ++ m) (validate s))

instance Arbitrary Signup where
  arbitrary = Signup <$> arbitrary <*> arbitrary <*> arbitrary

main :: IO ()
main = do
  putStrLn "--- valid signups ---"
  vs <- sample' (arbitrary :: Gen ValidSignup)
  mapM_ print (take 4 vs)

  putStrLn ""
  putStrLn "--- invalid signups (one thing broken each) ---"
  is <- sample' (arbitrary :: Gen InvalidSignup)
  mapM_ print (take 6 is)

  putStrLn ""
  putStrLn "--- properties ---"
  putStr "valid accepted       : " >> quickCheck prop_validAccepted
  putStr "invalid rejected     : " >> quickCheck prop_invalidRejected
  putStr "rejected for reason  : " >> quickCheck prop_invalidRightReason
  putStr "never crashes        : " >> quickCheck prop_neverCrashes

-- 「1ヶ所だけ壊す」方式の利点:
--   * どの検査が効いているかが1対1で分かる
--   * 検査を1つ消すと、対応するプロパティだけが落ちる (原因が即分かる)
--   * 「全部ランダムな文字列」では、たいてい複数のエラーが同時に出て
--     どの検査が動いたのか判別できない
--
-- 演習:
--   validate から [ MailNoAt | '@' `notElem` m ] の行を消してみてください。
--   prop_invalidRightReason だけが、Breakage = BreakMail の反例で落ちます。
