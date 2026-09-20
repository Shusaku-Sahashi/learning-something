-- Example 66: プロパティ全体を修飾する道具
--
-- 個々の入力ではなく、「テストの回し方」を変える道具たちです。
--
-- 実行: runghc Example66.hs
module Main (main) where

import Test.QuickCheck

prop_simple :: [Int] -> Bool
prop_simple xs = reverse (reverse xs) == xs

prop_fails :: [Int] -> Bool
prop_fails xs = length xs < 5

------------------------------------------------------------
-- withMaxSuccess :: Int -> prop -> Property
--   このプロパティだけテスト回数を変える。
--   quickCheckWith より局所的で、プロパティの定義に書けるのが利点。
------------------------------------------------------------
prop_manyTests :: [Int] -> Property
prop_manyTests xs = withMaxSuccess 2000 (reverse (reverse xs) === xs)

------------------------------------------------------------
-- once :: prop -> Property
--   1回だけ実行する。引数のないプロパティ (具体例のテスト) に使う。
------------------------------------------------------------
prop_specificCase :: Property
prop_specificCase = once (reverse [1, 2, 3 :: Int] === [3, 2, 1])

------------------------------------------------------------
-- again :: prop -> Property
--   once の効果を打ち消す。
------------------------------------------------------------
prop_againDemo :: [Int] -> Property
prop_againDemo xs = again (reverse (reverse xs) === xs)

------------------------------------------------------------
-- mapSize :: (Int -> Int) -> prop -> Property
--   サイズパラメータを変換する。
--   「大きい入力でだけ試したい」「小さい入力に絞りたい」ときに使う。
------------------------------------------------------------
-- ★ 落とし穴
--   次のように書いても効きません。
--
--     prop_bad :: [Int] -> Property
--     prop_bad xs = mapSize (const 3) (length xs <= 3)
--
--   xs はプロパティの引数なので、mapSize が評価される時点では
--   もう生成済みです。mapSize が効くのは「その内側で生成される値」だけ。
--   プロパティ全体を包んでください。
prop_smallOnly :: Property
prop_smallOnly = mapSize (const 3) (\xs -> length (xs :: [Int]) <= 3)

prop_bigOnly :: Property
prop_bigOnly = mapSize (* 5) (\xs -> length (xs :: [Int]) >= 0)

-- forAll の中で生成する場合も同じです。包む位置に注意してください。
prop_smallInside :: Property
prop_smallInside = mapSize (const 3) (forAll arbitrary (\xs -> length (xs :: [Int]) <= 3))

------------------------------------------------------------
-- expectFailure :: prop -> Property
--   「このプロパティは失敗するはず」を表明する。
--   バグの存在を記録したり、生成器が十分多様であることを確かめるのに使う。
------------------------------------------------------------
prop_knownBug :: Property
prop_knownBug = expectFailure (\xs -> length (xs :: [Int]) < 5)

-- 生成器が「空でないリストも作れる」ことの確認
prop_generatorReachesNonEmpty :: Property
prop_generatorReachesNonEmpty = expectFailure (\xs -> null (xs :: [Int]))

------------------------------------------------------------
-- within :: Int -> prop -> Property
--   マイクロ秒単位のタイムアウト。無限ループの検出に使う。
------------------------------------------------------------
slowFib :: Int -> Integer
slowFib n
  | n < 2     = fromIntegral n
  | otherwise = slowFib (n - 1) + slowFib (n - 2)

prop_fibFast :: Property
prop_fibFast =
  forAll (choose (0, 20)) $ \n ->
    within 2000000 (slowFib n >= 0)

------------------------------------------------------------
-- noShrinking / verbose / verboseShrinking
------------------------------------------------------------
prop_noShrink :: [Int] -> Property
prop_noShrink xs = noShrinking (length xs < 5)

main :: IO ()
main = do
  putStr "plain                 : " >> quickCheck prop_simple
  putStr "withMaxSuccess 2000   : " >> quickCheck prop_manyTests
  putStr "once                  : " >> quickCheck prop_specificCase
  putStr "again                 : " >> quickCheck prop_againDemo
  putStr "mapSize (const 3)     : " >> quickCheck prop_smallOnly
  putStr "mapSize (*5)          : " >> quickCheck prop_bigOnly
  putStr "mapSize + forAll      : " >> quickCheck prop_smallInside
  putStr "expectFailure         : " >> quickCheck prop_knownBug
  putStr "generator reaches [x] : " >> quickCheck prop_generatorReachesNonEmpty
  putStr "within (timeout)      : " >> quickCheck prop_fibFast
  putStrLn ""

  putStrLn "--- with and without shrinking ---"
  putStrLn "shrinking on:"
  quickCheck prop_fails
  putStrLn "shrinking off:"
  quickCheck prop_noShrink
  putStrLn ""

  putStrLn "--- verbose (first few generated inputs) ---"
  quickCheckWith stdArgs { maxSuccess = 3 } (verbose prop_simple)

-- 実務での使いどころ:
--
--   withMaxSuccess
--     重要なプロパティだけ試行回数を増やす。
--     「この1本は 10000 回回したい」をコードに書ける。
--
--   once
--     具体例のテストをプロパティと同じ枠組みで書きたいとき。
--     回帰テスト (過去に見つかった反例を固定する) に便利です (Example 98)。
--
--   mapSize
--     「小さい入力だけで速く回す」開発中のモードを作れる。
--     mapSize (const 5) でごく小さい入力に固定できます。
--
--   expectFailure
--     * 既知のバグを記録し、直ったら CI が教えてくれるようにする
--     * 生成器のカバレッジを確認する (上の例)
--     * 「このプロパティは成り立たないはず」という設計判断を明文化する
--
--   within
--     性能の回帰を検出する。ただし CI の負荷で揺れるので、
--     余裕を持った値にしてください。
