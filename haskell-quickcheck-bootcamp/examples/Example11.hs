-- Example 11: パターン1「往復 (round-trip)」
--
-- プロパティを思いつくコツは「型」ではなく「パターン」で覚えることです。
-- 最初に覚えるべきは往復 (round-trip) です。
--
--   decode (encode x) == x
--
-- 「書き出して読み戻したら元に戻る」型の性質は、実務で一番よく出てきて、
-- しかも一番よくバグが見つかります。
--
-- 実行: runghc Example11.hs
module Main (main) where

import Test.QuickCheck

-- show / read の往復
prop_showReadInt :: Int -> Property
prop_showReadInt x = read (show x) === x

prop_showReadList :: [Int] -> Property
prop_showReadList xs = read (show xs) === xs

prop_showReadPair :: (Int, Bool) -> Property
prop_showReadPair p = read (show p) === p

-- ★ Double では素直に往復しません。NaN は自分自身と等しくないからです。
--   これは show/read のバグではなく、Eq Double の性質です。
--   「往復プロパティが失敗したら、まず等価性の定義を疑う」の典型例です。
prop_showReadDouble :: Double -> Property
prop_showReadDouble x = read (show x) === x

-- NaN を避ければ通ります。
prop_showReadDoubleSane :: Double -> Property
prop_showReadDoubleSane x =
  not (isNaN x) ==> read (show x) === x

main :: IO ()
main = do
  putStr "show/read Int    : " >> quickCheck prop_showReadInt
  putStr "show/read [Int]  : " >> quickCheck prop_showReadList
  putStr "show/read (a,b)  : " >> quickCheck prop_showReadPair
  putStrLn ""
  putStrLn "--- Double: NaN makes the naive round trip fail ---"
  putStr "naive            : " >> quickCheck prop_showReadDouble
  putStr "NaN excluded    : " >> quickCheck prop_showReadDoubleSane
  putStrLn ""
  putStrLn "--- a closer look at NaN ---"
  let nan = 0 / 0 :: Double
  putStrLn ("  nan == nan  -> " ++ show (nan == nan))
  putStrLn ("  read(show nan) == nan -> " ++ show (read (show nan) == nan))

-- 往復プロパティを探す場所:
--   JSON / YAML / CSV のエンコーダとデコーダ
--   シリアライズ (binary, cereal)
--   パーサと pretty printer (Ex 91)
--   URL エンコード / Base64 / パーセントエンコード
--   圧縮と展開
--   データベースへの保存と読み出し
--
-- 注意:
--   往復が成り立つのは encode が単射のときだけです。
--   「空白の量は復元されない pretty printer」のように情報が落ちる場合は、
--   逆向きの往復 (encode (decode s) == s) は成り立ちません。
--   どちら向きが成り立つのかを意識して書き分けてください。
