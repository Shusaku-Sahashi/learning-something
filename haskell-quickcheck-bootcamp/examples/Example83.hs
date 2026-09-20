-- Example 83: 例外をテストする
--
-- 「この入力では例外を投げるべき」という仕様も、プロパティで書けます。
--
-- 実行: runghc Example83.hs
module Main (main) where

import Control.Exception
import Test.QuickCheck

------------------------------------------------------------
-- 対象: わざと例外を投げる関数たち
------------------------------------------------------------
data AppError
  = NotFound String
  | Invalid String
  deriving (Show, Eq)

instance Exception AppError

lookupUser :: Int -> IO String
lookupUser uid
  | uid <= 0  = throwIO (Invalid ("bad id: " ++ show uid))
  | uid > 100 = throwIO (NotFound ("no user " ++ show uid))
  | otherwise = pure ("user" ++ show uid)

-- 純粋関数が投げる例外 (部分関数)
unsafeHead :: [a] -> a
unsafeHead = head

------------------------------------------------------------
-- 道具: try で例外を捕まえて Either にする
------------------------------------------------------------
-- try :: Exception e => IO a -> IO (Either e a)

-- 正常系: 有効な ID では例外が出ない
prop_validIdSucceeds :: Property
prop_validIdSucceeds =
  forAll (choose (1, 100)) $ \uid -> ioProperty $ do
    r <- try (lookupUser uid) :: IO (Either AppError String)
    pure (case r of
            Right name -> counterexample name (property True)
            Left e     -> counterexample ("unexpected: " ++ show e) (property False))

-- 異常系1: 0 以下の ID では Invalid を投げる
prop_nonPositiveIsInvalid :: Property
prop_nonPositiveIsInvalid =
  forAll (choose (-1000, 0)) $ \uid -> ioProperty $ do
    r <- try (lookupUser uid) :: IO (Either AppError String)
    pure (case r of
            Left (Invalid _) -> property True
            other            -> counterexample (show other) (property False))

-- 異常系2: 101 以上の ID では NotFound を投げる
prop_tooLargeIsNotFound :: Property
prop_tooLargeIsNotFound =
  forAll (choose (101, 100000)) $ \uid -> ioProperty $ do
    r <- try (lookupUser uid) :: IO (Either AppError String)
    pure (case r of
            Left (NotFound _) -> property True
            other             -> counterexample (show other) (property False))

-- どんな ID でも「例外を投げるか、値を返すか」のどちらかで、
-- プログラムが停止しないこと
prop_alwaysTerminates :: Int -> Property
prop_alwaysTerminates uid = ioProperty $ do
  r <- try (lookupUser uid) :: IO (Either AppError String)
  pure (case r of
          Left _  -> True
          Right s -> not (null s))

------------------------------------------------------------
-- 純粋なコードの例外を捕まえる: evaluate + try
------------------------------------------------------------
-- 純粋な式は遅延評価されるので、try で包むだけでは捕まりません。
-- evaluate で強制的に評価する必要があります。
prop_headThrowsOnEmpty :: Property
prop_headThrowsOnEmpty = ioProperty $ do
  r <- try (evaluate (unsafeHead ([] :: [Int]))) :: IO (Either SomeException Int)
  pure (case r of
          Left _  -> True
          Right _ -> False)

prop_headWorksOnNonEmpty :: NonEmptyList Int -> Property
prop_headWorksOnNonEmpty (NonEmpty xs) = ioProperty $ do
  r <- try (evaluate (unsafeHead xs)) :: IO (Either SomeException Int)
  pure (case r of
          Left _  -> False
          Right v -> v == head xs)

------------------------------------------------------------
-- よくある間違い: try を付けても捕まらない例
------------------------------------------------------------
-- try (pure (head [])) は、head [] を評価しないので例外が出ません。
-- Right <thunk> が返り、あとで別の場所で落ちます。
lazyTrapDemo :: IO ()
lazyTrapDemo = do
  withoutEvaluate <- try (pure (unsafeHead ([] :: [Int]))) :: IO (Either SomeException Int)
  putStrLn ("  try (pure (head []))     -> " ++ describe withoutEvaluate)
  withEvaluate <- try (evaluate (unsafeHead ([] :: [Int]))) :: IO (Either SomeException Int)
  putStrLn ("  try (evaluate (head [])) -> " ++ describe withEvaluate)
  where
    describe (Left e)  = "Left  (caught: " ++ takeWhile (/= '\n') (show e) ++ ")"
    describe (Right _) = "Right (NOT caught: the thunk escaped)"

------------------------------------------------------------
-- total を使った簡便法 (Example 19)
------------------------------------------------------------
prop_noCrashTotal :: [Int] -> Property
prop_noCrashTotal xs = total (safeHead xs)
  where
    safeHead []      = Nothing
    safeHead (y : _) = Just y

main :: IO ()
main = do
  putStr "valid id succeeds    : " >> quickCheck prop_validIdSucceeds
  putStr "non-positive invalid : " >> quickCheck prop_nonPositiveIsInvalid
  putStr "too large not found  : " >> quickCheck prop_tooLargeIsNotFound
  putStr "always terminates    : " >> quickCheck prop_alwaysTerminates
  putStrLn ""

  putStr "head [] throws       : " >> quickCheck prop_headThrowsOnEmpty
  putStr "head (x:xs) works    : " >> quickCheck prop_headWorksOnNonEmpty
  putStrLn ""

  putStrLn "--- the laziness trap ---"
  lazyTrapDemo
  putStrLn ""

  putStr "safeHead never crashes: " >> quickCheck prop_noCrashTotal

-- まとめ:
--
--   IO の例外          try action
--   純粋な式の例外      try (evaluate expr)
--   「落ちないこと」     total value   (NFData が要る)
--
--   ★ evaluate を忘れると捕まりません。
--     try (pure expr)     -- ダメ。expr は評価されない
--     try (evaluate expr) -- OK
--
--   ★ evaluate は WHNF (先頭だけ) までしか評価しません。
--     リストの途中に error があると捕まりません。
--     そこまで必要なら force (deepseq) や total を使ってください。
--
-- 例外のプロパティを書くときのコツ:
--   「例外が出る」だけでなく「どの例外が出るか」まで確かめること。
--   上の prop_nonPositiveIsInvalid は Invalid かどうかまで見ています。
--   SomeException で受けてしまうと、
--   「意図しない別のバグで落ちた」場合も成功扱いになってしまいます。
