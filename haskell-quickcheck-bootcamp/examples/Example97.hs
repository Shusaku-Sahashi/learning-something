-- Example 97: 既存プロジェクトに導入する
--
-- 「今ある単体テストをプロパティに育てる」手順です。
-- 最初から全部書き直す必要はありません。
--
-- 実行: runghc Example97.hs
module Main (main) where

import Data.Char (toLower, isSpace)
import Test.QuickCheck

------------------------------------------------------------
-- 題材: 検索キーワードの正規化
------------------------------------------------------------
-- 前後の空白を削り、連続する空白を1つにし、小文字化する
normalize :: String -> String
normalize = unwords . words . map toLower

------------------------------------------------------------
-- STEP 0: 今ある単体テスト
------------------------------------------------------------
existingUnitTests :: [(String, Bool)]
existingUnitTests =
  [ ("lowercases",     normalize "ABC" == "abc")
  , ("trims",          normalize "  abc  " == "abc")
  , ("collapses",      normalize "a   b" == "a b")
  , ("empty",          normalize "" == "")
  ]

------------------------------------------------------------
-- STEP 1: 単体テストを「プロパティの具体例」として残す
------------------------------------------------------------
-- once を使えば、プロパティと同じ枠組みで書けます。
-- テストランナーを2つ持たなくて済みます。
prop_existingCases :: Property
prop_existingCases = once $
  conjoin
    [ counterexample "lowercases" (normalize "ABC" === "abc")
    , counterexample "trims"      (normalize "  abc  " === "abc")
    , counterexample "collapses"  (normalize "a   b" === "a b")
    , counterexample "empty"      (normalize "" === "")
    ]

------------------------------------------------------------
-- STEP 2: 単体テストを一般化する
------------------------------------------------------------
-- 「ABC -> abc」は「大文字が残らない」の具体例です。
prop_noUpperCase :: String -> Bool
prop_noUpperCase s = all (\c -> c == toLower c) (normalize s)

-- 「  abc  -> abc」は「前後に空白が残らない」の具体例です。
prop_noLeadingTrailingSpace :: String -> Property
prop_noLeadingTrailingSpace s =
  let r = normalize s
  in counterexample (show r) $
       property (null r || (not (isSpace (head r)) && not (isSpace (last r))))

-- 「a   b -> a b」は「空白が2つ続かない」の具体例です。
prop_noDoubleSpace :: String -> Property
prop_noDoubleSpace s =
  let r = normalize s
  in counterexample (show r) $
       property (not (any (\(a, b) -> isSpace a && isSpace b) (zip r (drop 1 r))))

------------------------------------------------------------
-- STEP 3: 一般的な性質を足す (Ch2 のパターン集を使う)
------------------------------------------------------------
-- 冪等性
prop_idempotent :: String -> Property
prop_idempotent s = normalize (normalize s) === normalize s

-- 単語の列は保存される (情報が落ちていない)
prop_wordsPreserved :: String -> Property
prop_wordsPreserved s = words (normalize s) === map (map toLower) (words s)

-- 全域性
prop_total :: String -> Property
prop_total s = total (normalize s)

-- 長さは増えない
prop_neverGrows :: String -> Bool
prop_neverGrows s = length (normalize s) <= length s

------------------------------------------------------------
-- STEP 4: 生成器を仕事の入力に近づける (Ch7)
------------------------------------------------------------
-- ランダムな String は、現実の検索キーワードとは似ていません。
-- 実際に来る形に近い生成器を用意します。
genSearchQuery :: Gen String
genSearchQuery = do
  ws <- listOf genWord
  seps <- vectorOf (max 0 (length ws - 1)) genSep
  lead <- genPad
  trail <- genPad
  pure (lead ++ interleave ws seps ++ trail)
  where
    genWord = do
      n <- choose (1, 8)
      vectorOf n (elements (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9']))
    genSep = do
      n <- choose (1, 3)
      vectorOf n (elements " \t")
    genPad = do
      n <- choose (0, 3)
      vectorOf n (elements " \t")
    interleave (x : xs) (s : ss) = x ++ s ++ interleave xs ss
    interleave xs _              = concat xs

prop_realisticIdempotent :: Property
prop_realisticIdempotent =
  forAll genSearchQuery $ \s ->
    classify (null (words s))         "empty query"    $
    classify (length (words s) == 1)  "one word"       $
    classify (length (words s) >= 3)  "three or more"  $
      normalize (normalize s) === normalize s

main :: IO ()
main = do
  putStrLn "--- STEP 0: the unit tests you already have ---"
  mapM_ (\(n, ok) -> putStrLn ("  " ++ (if ok then "PASS " else "FAIL ") ++ n))
        existingUnitTests
  putStrLn ""

  putStrLn "--- STEP 1: the same cases, as a property ---"
  putStr "existing cases      : " >> quickCheck prop_existingCases
  putStrLn ""

  putStrLn "--- STEP 2: generalise each unit test ---"
  putStr "no upper case       : " >> quickCheck prop_noUpperCase
  putStr "no outer space      : " >> quickCheck prop_noLeadingTrailingSpace
  putStr "no double space     : " >> quickCheck prop_noDoubleSpace
  putStrLn ""

  putStrLn "--- STEP 3: add the standard patterns ---"
  putStr "idempotent          : " >> quickCheck prop_idempotent
  putStr "words preserved     : " >> quickCheck prop_wordsPreserved
  putStr "never grows         : " >> quickCheck prop_neverGrows
  putStr "total               : " >> quickCheck prop_total
  putStrLn ""

  putStrLn "--- STEP 4: generate realistic input ---"
  qs <- sample' genSearchQuery
  mapM_ (putStrLn . ("  " ++) . show) (take 5 qs)
  quickCheckWith stdArgs { maxSuccess = 500 } prop_realisticIdempotent

-- 導入の順番 (実プロジェクトでそのまま使えます):
--
--   1. 既存の単体テストは消さない。once でプロパティの形に包むだけ。
--   2. 1つの単体テストにつき、1つ「一般化した性質」を書く。
--      「この例が通るべき理由は何か?」を言葉にすると、それが性質です。
--   3. Ch2 のパターン集を順に当てはめる。
--      往復 / 不変条件 / 冪等性 / 代数法則 / オラクル / メタモルフィック / 全域性
--   4. 生成器を現実の入力に近づける。classify で分布を確認する。
--   5. バグが見つかったら、直して回帰テストを足す (Example 95)。
--
-- どこから始めるか:
--   * 純粋関数から。IO が絡むところは後回し。
--   * 「変換」系の関数が狙い目。往復や冪等性がすぐ書けます。
--   * バグがよく出るモジュールから。効果が目に見えます。
--
-- やってはいけないこと:
--   * 既存の単体テストを消してプロパティに置き換える。
--     単体テストは「この具体例は絶対に守る」という宣言です。両方あってよい。
--   * 最初から全モジュールに入れようとする。1つで成功体験を作ってから広げる。
