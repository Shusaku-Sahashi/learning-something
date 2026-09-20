-- Example 42: 自作の型で Fun を使う (CoArbitrary と Function)
--
-- Fun a b を自作の型 a に対して使うには、2つのインスタンスが必要です。
--   CoArbitrary a : 「a の値を乱数の種に混ぜる方法」
--   Function a    : 「a から b への関数を表として表す方法」
--
-- 実行: runghc Example42.hs
{-# LANGUAGE DeriveGeneric #-}
module Main (main) where

import GHC.Generics (Generic)
import Test.QuickCheck

------------------------------------------------------------
-- 方法1: Generic から自動導出する (簡単。こちらを推奨)
------------------------------------------------------------
data Color = Red | Green | Blue
  deriving (Show, Eq, Ord, Enum, Bounded, Generic)

instance Arbitrary Color where
  arbitrary = arbitraryBoundedEnum

instance CoArbitrary Color            -- Generic から自動導出
instance Function Color where
  function = functionMap fromEnum toEnum

data Point = Point Int Int
  deriving (Show, Eq, Generic)

instance Arbitrary Point where
  arbitrary = Point <$> arbitrary <*> arbitrary

instance CoArbitrary Point            -- Generic から自動導出
instance Function Point where
  -- functionMap で「既に Function インスタンスを持つ型」に変換します。
  function = functionMap (\(Point x y) -> (x, y)) (uncurry Point)

------------------------------------------------------------
-- 方法2: 手で書く (仕組みを知るため)
------------------------------------------------------------
data Light = Off | On
  deriving (Show, Eq)

instance Arbitrary Light where
  arbitrary = elements [Off, On]

instance CoArbitrary Light where
  -- variant n は「乱数の流れを n 番目の枝に分岐させる」操作です。
  -- 値ごとに違う番号を渡すことで、「入力が違えば出力も違う関数」が作れます。
  coarbitrary Off = variant (0 :: Int)
  coarbitrary On  = variant (1 :: Int)

instance Function Light where
  function = functionMap toBool fromBool
    where toBool Off = False
          toBool On  = True
          fromBool False = Off
          fromBool True  = On

------------------------------------------------------------
-- プロパティ
------------------------------------------------------------
-- 自作型を引数に取る関数を生成できる
prop_colorFunTotal :: Fun Color Int -> Color -> Bool
prop_colorFunTotal (Fn f) c = f c == f c      -- 決定的であること

prop_colorMapFusion :: Fun Color Int -> Fun Int Int -> [Color] -> Property
prop_colorMapFusion (Fn f) (Fn g) cs =
  map g (map f cs) === map (g . f) cs

prop_pointFun :: Fun Point Bool -> [Point] -> Bool
prop_pointFun (Fn p) ps = all p (filter p ps)

prop_lightFun :: Fun Light String -> Bool
prop_lightFun (Fn f) = f Off == f Off && f On == f On

-- CoArbitrary があると、「自作型を引数に取る関数」を arbitrary で作れます。
-- (ただし Show できないので、プロパティの引数には Fun を使うこと)
prop_coarbitraryWorks :: Property
prop_coarbitraryWorks =
  forAllBlind (arbitrary :: Gen (Color -> Int)) (\f -> f Red == f Red)

------------------------------------------------------------
-- 生成された関数が「ちゃんと入力を見ている」ことの確認
------------------------------------------------------------
-- もし CoArbitrary が壊れていると、常に定数を返す関数しか作られません。
prop_notAlwaysConstant :: Property
prop_notAlwaysConstant =
  expectFailure (forAll (arbitrary :: Gen (Fun Color Int))
                        (\(Fn f) -> f Red == f Green && f Green == f Blue))

main :: IO ()
main = do
  putStrLn "--- generated functions on a custom enum (printed as <fun>) ---"
  fs <- sample' (arbitrary :: Gen (Fun Color Int))
  mapM_ print (take 4 fs)

  putStrLn ""
  putStrLn "--- generated functions on a custom record ---"
  ps <- sample' (arbitrary :: Gen (Fun Point Bool))
  mapM_ print (take 3 ps)

  putStrLn ""
  putStrLn "--- hand-written instances ---"
  ls <- sample' (arbitrary :: Gen (Fun Light String))
  mapM_ print (take 3 ls)
  putStrLn "  (see Example 41: the function table appears only in counterexamples)"

  putStrLn ""
  putStrLn "--- properties ---"
  putStr "deterministic      : " >> quickCheck prop_colorFunTotal
  putStr "map fusion         : " >> quickCheck prop_colorMapFusion
  putStr "point predicate    : " >> quickCheck prop_pointFun
  putStr "light function     : " >> quickCheck prop_lightFun
  putStr "coarbitrary works  : " >> quickCheck prop_coarbitraryWorks
  putStr "not always constant: " >> quickCheck prop_notAlwaysConstant

-- まとめ:
--   CoArbitrary a  -- a を「関数の入力」として使うために必要
--   Function a     -- Fun a b を Show / shrink できるようにするために必要
--
--   どちらも Generic から自動導出できます。
--     deriving (Generic)
--     instance CoArbitrary MyType
--     instance Function MyType where function = functionMap toTuple fromTuple
--
--   functionMap は「既に Function を持つ型へ変換する」ヘルパーです。
--   タプル、Int、Bool、リストなどは最初から Function を持っています。
--
-- expectFailure は「このプロパティは失敗するはず」を表明する道具です。
-- 「常に定数を返す関数しか生成されない」ことがないのを確かめています。
