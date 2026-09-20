-- Example 04: Bool と Property
--
-- quickCheck に渡せるのは「Testable なもの」です。
-- Bool も Property も Testable ですが、役割が違います。
--
-- 実行: runghc Example04.hs
module Main (main) where

import Test.QuickCheck

-- (A) Bool を返すプロパティ。一番単純な形。
prop_asBool :: [Int] -> Bool
prop_asBool xs = length (xs ++ xs) == 2 * length xs

-- (B) Property を返すプロパティ。
--     property 関数で Bool を Property に持ち上げられます。
--     Property にすると、あとで counterexample や classify などの
--     「追加情報」を合成できるようになります (Example 09, Ch7)。
prop_asProperty :: [Int] -> Property
prop_asProperty xs = property (length (xs ++ xs) == 2 * length xs)

-- (C) 引数がないプロパティ。ただの Bool でも通ります。
--     ランダム生成する入力がないので、1回だけ評価されます。
prop_noArgs :: Bool
prop_noArgs = sum [1 .. 100 :: Int] == 5050

-- (D) IO アクションの結果をプロパティにしたいときは ioProperty を使います。
--     (IO () そのものは Testable ではありません。Ch8 で詳しく扱います)
prop_io :: Int -> Property
prop_io x = ioProperty (return (abs x >= 0))

main :: IO ()
main = do
  putStr "Bool       : " >> quickCheck prop_asBool
  putStr "Property   : " >> quickCheck prop_asProperty
  putStr "no args    : " >> quickCheck prop_noArgs
  putStr "ioProperty : " >> quickCheck prop_io

-- 覚え方:
--   とりあえず Bool で書き始める。
--   条件や情報を足したくなったら Property に変える。
--   Property -> Bool の変換はできないので、迷ったら Property にしておけば損はしません。
--
-- ちなみに Testable のインスタンスには
--   Bool, Property, Result, Discard, Gen prop, (a -> prop) などがあり、
--   「引数を取る関数」自体が Testable なので、引数が何個あっても quickCheck に渡せます。
