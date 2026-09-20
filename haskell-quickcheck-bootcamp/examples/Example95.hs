-- Example 95: 回帰テストを作る
--
-- QuickCheck が見つけた反例を、二度と再発させないための仕組みです。
--
-- 実行: runghc Example95.hs
module Main (main) where

import Test.QuickCheck

------------------------------------------------------------
-- なぜ回帰テストが要るのか
------------------------------------------------------------
-- ランダムテストには次の弱点があります。
--   * 同じ反例が次の実行でも出るとは限らない
--   * シードを固定しても、生成器やプロパティを変えると別の入力になる
--   * 「直ったこと」を保証するには、その入力を必ず試す必要がある
--
-- そこで、見つかった反例を「固定のテスト」として残します。

------------------------------------------------------------
-- 対象のコード
------------------------------------------------------------
-- 一度バグがあって直した関数、という想定
ellipsis :: Int -> String -> String
ellipsis n s
  | n <= 0        = ""
  | length s <= n = s
  | n <= 3        = take n s          -- ★ #3 で追加した分岐
  | otherwise     = take (n - 3) s ++ "..."

ensureTrailingNewline :: String -> String
ensureTrailingNewline s
  | not (null s) && last s == '\n' = s    -- ★ #4 で null チェックを追加
  | otherwise                      = s ++ "\n"

------------------------------------------------------------
-- 回帰テスト: once を使って「1回だけ実行する」プロパティにする
------------------------------------------------------------
-- 書式のおすすめ:
--   * 番号を振る (#3, #4 ...)
--   * いつ・どのプロパティで見つかったかを書く
--   * 何が原因だったかを1行で書く
--   * conjoin で関連ケースをまとめる

-- #3 2026-09-20: prop_ellipsisBounded が (n=3, "abcdef") で落ちた。
--   n <= 3 のとき take (n-3) s ++ "..." が長さ 3 を超えていた。
regr_ellipsisSmallN :: Property
regr_ellipsisSmallN = once $
  conjoin
    [ counterexample "n = 0" (ellipsis 0 "abcdef" === "")
    , counterexample "n = 1" (ellipsis 1 "abcdef" === "a")
    , counterexample "n = 3" (ellipsis 3 "abcdef" === "abc")
    , counterexample "n = 4" (ellipsis 4 "abcdef" === "a...")
    , counterexample "n = 6" (ellipsis 6 "abcdef" === "abcdef")
    , counterexample "n = 9" (ellipsis 9 "abcdef" === "abcdef")
    ]

-- #4 2026-09-20: prop_newlineIdempotent が "" で落ちた。
--   last "" が例外になっていた。
regr_newlineEmpty :: Property
regr_newlineEmpty = once $
  conjoin
    [ counterexample "empty"          (ensureTrailingNewline "" === "\n")
    , counterexample "already ends"   (ensureTrailingNewline "a\n" === "a\n")
    , counterexample "needs one"      (ensureTrailingNewline "a" === "a\n")
    , counterexample "just a newline" (ensureTrailingNewline "\n" === "\n")
    ]

------------------------------------------------------------
-- 元のプロパティも残す (回帰テストは置き換えではなく追加)
------------------------------------------------------------
prop_ellipsisBounded :: NonNegative Int -> String -> Property
prop_ellipsisBounded (NonNegative n) s =
  counterexample (show (n, s, ellipsis n s)) (length (ellipsis n s) <= n)

prop_newlineIdempotent :: String -> Property
prop_newlineIdempotent s =
  ensureTrailingNewline (ensureTrailingNewline s) === ensureTrailingNewline s

------------------------------------------------------------
-- 反例を自動で回帰テストの形に整形するヘルパー
------------------------------------------------------------
-- 「落ちたら、そのまま貼れるコードを出力する」と、回帰テストを書くのが楽になります。
suggestRegression :: Testable p => String -> p -> IO ()
suggestRegression name p = do
  r <- quickCheckWithResult stdArgs { chatty = False } p
  case r of
    Failure { failingTestCase = tc, numShrinks = sh } -> do
      putStrLn ("  " ++ name ++ ": FAILED (" ++ show sh ++ " shrinks)")
      putStrLn "  add this to Props/Regression.hs:"
      putStrLn ""
      putStrLn ("    -- TODO(date): found by " ++ name)
      putStrLn ("    regr_TODO :: Property")
      putStrLn ("    regr_TODO = once $")
      mapM_ (\(i, v) -> putStrLn ("      -- arg " ++ show (i :: Int) ++ ": " ++ oneLine v))
            (zip [1 ..] tc)
      putStrLn "      undefined  -- fill in the expected result"
      putStrLn ""
    _ -> putStrLn ("  " ++ name ++ ": passed")
  where oneLine = takeWhile (/= '\n')

-- わざと壊した実装で、上のヘルパーを試す
ellipsisBuggy :: Int -> String -> String
ellipsisBuggy n s
  | length s <= n = s
  | otherwise     = take (n - 3) s ++ "..."    -- n <= 3 の分岐がない

prop_buggyBounded :: NonNegative Int -> String -> Property
prop_buggyBounded (NonNegative n) s =
  counterexample (show (n, s, ellipsisBuggy n s))
    (length (ellipsisBuggy n s) <= n)

main :: IO ()
main = do
  putStrLn "--- regression tests (fixed inputs) ---"
  putStr "#3 ellipsis small n : " >> quickCheck regr_ellipsisSmallN
  putStr "#4 newline on empty : " >> quickCheck regr_newlineEmpty
  putStrLn ""

  putStrLn "--- the original properties (still running) ---"
  putStr "ellipsis bounded    : " >> quickCheck prop_ellipsisBounded
  putStr "newline idempotent  : " >> quickCheck prop_newlineIdempotent
  putStrLn ""

  putStrLn "--- what a fresh failure looks like ---"
  suggestRegression "prop_buggyBounded" prop_buggyBounded

-- 回帰テストの運用ルール:
--
--   1. バグを直したら、必ず回帰テストを1本足す。
--      「プロパティを直したから大丈夫」ではありません。
--      プロパティは確率的にしか、その入力を試しません。
--
--   2. 反例そのものではなく「反例の周辺」も入れる。
--      n = 3 で落ちたなら、n = 0, 1, 2, 3, 4 を全部入れます。
--      境界の隣は、たいてい同じ原因で壊れます。
--
--   3. コメントに「いつ・なぜ」を残す。
--      半年後の自分が「このテスト消していいのか」を判断できるように。
--
--   4. once を使う。
--      引数がないプロパティなので、1回実行すれば十分です。
--      once を付けないと同じテストを 100 回繰り返して無駄になります。
--
--   5. 専用のモジュールにまとめる。
--      test/Props/Regression.hs のように1ファイルに集めると、
--      「このプロジェクトで過去に何が起きたか」の記録になります。
--
-- ../project/test/Props/Regression.hs に実例があります。
