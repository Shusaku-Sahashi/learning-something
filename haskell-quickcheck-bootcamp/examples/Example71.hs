-- Example 71: collect で分布を見る
--
-- ここから Ch7「何をテストできているのか測る」です。
-- テストが通っても、そもそも意味のある入力が来ていなければ無意味です。
--
-- 実行: runghc Example71.hs
module Main (main) where

import Test.QuickCheck

-- collect :: (Show a, Testable prop) => a -> prop -> Property
--   値を記録して、最後に頻度表として表示します。

-- リストの長さの分布を見る
prop_lengthDistribution :: [Int] -> Property
prop_lengthDistribution xs =
  collect (length xs) (reverse (reverse xs) == xs)

-- 長さをそのまま出すと種類が多すぎるので、まとめる
prop_lengthBucketed :: [Int] -> Property
prop_lengthBucketed xs =
  collect (bucket (length xs)) (reverse (reverse xs) == xs)
  where
    bucket n
      | n == 0    = "empty"
      | n == 1    = "singleton"
      | n <= 5    = "2-5"
      | n <= 20   = "6-20"
      | otherwise = "21+"

-- 値の符号の分布
prop_signDistribution :: Int -> Property
prop_signDistribution n =
  collect (signName n) (abs n >= 0 || n == minBound)
  where
    signName x | x < 0     = "negative"
               | x == 0    = "zero"
               | otherwise = "positive"

-- 複数の collect を重ねられる (別々の表が出ます)
prop_twoCollects :: [Int] -> Property
prop_twoCollects xs =
  collect (null xs) (collect (length xs `mod` 2 == 0) True)

main :: IO ()
main = do
  putStrLn "--- raw lengths (too many buckets to read) ---"
  quickCheckWith stdArgs { maxSuccess = 200 } prop_lengthDistribution
  putStrLn ""

  putStrLn "--- bucketed lengths (readable) ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_lengthBucketed
  putStrLn ""

  putStrLn "--- sign of a random Int ---"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_signDistribution
  putStrLn ""

  putStrLn "--- two collects at once ---"
  quickCheckWith stdArgs { maxSuccess = 500 } prop_twoCollects

-- 出力の読み方:
--
--   +++ OK, passed 1000 tests:
--   31.5% 6-20
--   28.4% 2-5
--   ...
--
-- パーセントは「全テスト中、その値だった割合」です。
--
-- collect で真っ先に確認すべきこと:
--   * 空・ゼロ・境界値がちゃんと出ているか
--   * 極端に偏っていないか
--   * 「絶対に来ないはずの値」が来ていないか
--
-- ★ よくある発見
--   「リストのテストのつもりが、8割が空リストだった」
--   「日付のテストのつもりが、すべて同じ月だった」
--   「エラーパスのテストのつもりが、一度もエラーになっていなかった」
--
--   どれも collect を1行足すだけで分かります。
