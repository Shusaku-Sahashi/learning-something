-- Example 70: Ch6 総合演習「予約システムの入力を設計する」
--
-- 前提条件を一切使わずに、複雑な制約を持つ入力を生成します。
--
-- 実行: runghc Example70.hs
module Main (main) where

import Data.List (sort, nub)
import Test.QuickCheck

------------------------------------------------------------
-- ドメイン: 会議室の予約
------------------------------------------------------------
-- 制約:
--   1. 開始時刻 < 終了時刻
--   2. 時刻は 0..1439 (分単位の1日)
--   3. 参加者は1人以上、重複なし
--   4. 部屋 ID は既知のものから選ぶ
--   5. 予約リストは、同じ部屋で時間が重ならない
------------------------------------------------------------
data Booking = Booking
  { room      :: String
  , startMin  :: Int
  , endMin    :: Int
  , attendees :: [String]
  }
  deriving (Show, Eq)

rooms :: [String]
rooms = ["A", "B", "C"]

people :: [String]
people = ["alice", "bob", "carol", "dave", "erin"]

validBooking :: Booking -> Bool
validBooking b =
  room b `elem` rooms
    && 0 <= startMin b && startMin b < endMin b && endMin b <= 1440
    && not (null (attendees b))
    && nub (attendees b) == attendees b
    && all (`elem` people) (attendees b)

overlaps :: Booking -> Booking -> Bool
overlaps x y =
  room x == room y && startMin x < endMin y && startMin y < endMin x

validSchedule :: [Booking] -> Bool
validSchedule bs =
  all validBooking bs
    && and [ not (overlaps x y) | (i, x) <- zip [0 :: Int ..] bs
                                , (j, y) <- zip [0 :: Int ..] bs
                                , i < j ]

------------------------------------------------------------
-- 生成器: 制約1〜4 を満たす1件
------------------------------------------------------------
newtype ValidBooking = ValidBooking Booking
  deriving (Show, Eq)

genAttendees :: Gen [String]
genAttendees = do
  n <- choose (1, length people)
  take n <$> shuffle people      -- shuffle + take で「重複なし」が保証される

instance Arbitrary ValidBooking where
  arbitrary = do
    r <- elements rooms
    s <- choose (0, 1439)
    e <- choose (s + 1, 1440)    -- 制約1 を生成で保証
    as <- genAttendees
    pure (ValidBooking (Booking r s e as))

  shrink (ValidBooking b) =
    -- ★ 注意: shrink (attendees b) と書くと、文字列そのものが縮んで
    --   "alice" -> "" のような、people に含まれない参加者ができてしまいます。
    --   shrinkList (const []) を使い、「要素を削るだけ」にします。
    [ ValidBooking b { attendees = as }
    | as <- shrinkList (const []) (attendees b)
    , not (null as)
    ] ++
    [ ValidBooking b { endMin = e }
    | e <- shrink (endMin b)
    , e > startMin b
    ] ++
    [ ValidBooking b { startMin = s }
    | s <- shrink (startMin b)
    , s < endMin b
    ]

------------------------------------------------------------
-- 生成器: 制約5 も満たすスケジュール全体
------------------------------------------------------------
-- 発想: 「重ならない予約列」を作るには、
--       時刻を昇順に取り、区間を順番に切り出せばよい。
newtype ValidSchedule = ValidSchedule [Booking]
  deriving (Show, Eq)

genScheduleForRoom :: String -> Gen [Booking]
genScheduleForRoom r = do
  n <- choose (0, 5)
  -- 2n 個の時刻を取り、昇順に並べて、重複を除いてからペアにする
  ts <- vectorOf (2 * n) (choose (0, 1440))
  let sorted = nub (sort ts)
      pairs  = toPairs sorted
  mapM (\(s, e) -> Booking r s e <$> genAttendees) (take n pairs)
  where
    toPairs (a : b : rest) = (a, b) : toPairs rest
    toPairs _              = []

instance Arbitrary ValidSchedule where
  arbitrary = do
    perRoom <- mapM genScheduleForRoom rooms
    pure (ValidSchedule (concat perRoom))
  shrink (ValidSchedule bs) =
    [ ValidSchedule bs' | bs' <- shrinkList (const []) bs ]
    -- 予約を削るだけなら、重ならない性質は保たれる

------------------------------------------------------------
-- テスト対象
------------------------------------------------------------
durationMin :: Booking -> Int
durationMin b = endMin b - startMin b

totalBookedMinutes :: String -> [Booking] -> Int
totalBookedMinutes r bs = sum [ durationMin b | b <- bs, room b == r ]

canBook :: [Booking] -> Booking -> Bool
canBook existing b = validBooking b && not (any (overlaps b) existing)

addBooking :: [Booking] -> Booking -> [Booking]
addBooking existing b
  | canBook existing b = b : existing
  | otherwise          = existing

------------------------------------------------------------
-- プロパティ (前提条件ゼロ)
------------------------------------------------------------
prop_bookingValid :: ValidBooking -> Bool
prop_bookingValid (ValidBooking b) = validBooking b

prop_bookingShrinkValid :: ValidBooking -> Bool
prop_bookingShrinkValid v = all (\(ValidBooking b) -> validBooking b) (shrink v)

prop_scheduleValid :: ValidSchedule -> Property
prop_scheduleValid (ValidSchedule bs) =
  counterexample (show bs) (validSchedule bs)

prop_scheduleShrinkValid :: ValidSchedule -> Bool
prop_scheduleShrinkValid v =
  all (\(ValidSchedule bs) -> validSchedule bs) (shrink v)

prop_durationPositive :: ValidBooking -> Bool
prop_durationPositive (ValidBooking b) = durationMin b > 0

prop_totalWithinDay :: ValidSchedule -> Bool
prop_totalWithinDay (ValidSchedule bs) =
  all (\r -> totalBookedMinutes r bs <= 1440) rooms

prop_addKeepsValid :: ValidSchedule -> ValidBooking -> Property
prop_addKeepsValid (ValidSchedule bs) (ValidBooking b) =
  counterexample (show (b, bs)) (validSchedule (addBooking bs b))

prop_addIdempotentWhenOverlapping :: ValidSchedule -> Property
prop_addIdempotentWhenOverlapping (ValidSchedule bs) =
  not (null bs) ==>
    forAll (elements bs) $ \b ->
      addBooking bs b === bs         -- 既にある予約は重なるので追加されない

main :: IO ()
main = do
  putStrLn "--- sample bookings ---"
  vbs <- sample' (arbitrary :: Gen ValidBooking)
  mapM_ print (take 3 vbs)
  putStrLn ""

  putStrLn "--- sample schedules (count per room) ---"
  vss <- sample' (arbitrary :: Gen ValidSchedule)
  mapM_ (\(ValidSchedule bs) ->
           putStrLn ("  " ++ show [ (r, length [ () | b <- bs, room b == r ]) | r <- rooms ]))
        (take 5 vss)
  putStrLn ""

  putStrLn "--- generators and shrinks ---"
  putStr "booking valid          : " >> quickCheck prop_bookingValid
  putStr "booking shrink valid   : " >> quickCheck prop_bookingShrinkValid
  putStr "schedule valid         : " >> quickCheck prop_scheduleValid
  putStr "schedule shrink valid  : " >> quickCheck prop_scheduleShrinkValid
  putStrLn ""

  putStrLn "--- domain properties ---"
  putStr "duration > 0           : " >> quickCheck prop_durationPositive
  putStr "total <= 1 day         : " >> quickCheck prop_totalWithinDay
  putStr "add keeps schedule ok  : " >> quickCheck prop_addKeepsValid
  putStr "re-adding does nothing : " >> quickCheck prop_addIdempotentWhenOverlapping

-- Ch6 のまとめ:
--
--   1. (==>) は「捨てる」だけ。「作る」わけではない
--   2. 捨てる数が多いと Gave up する。少なくても分布が歪む
--   3. 標準 Modifier で書ける条件は Modifier にする
--   4. 残りは生成器に移す。依存する値は do 記法で順に作る
--   5. 「重ならない区間」のような複雑な制約は、
--      「条件を検査する」のではなく「構成的に作る」
--      (上の genScheduleForRoom は、時刻を並べてペアにするだけで
--       重複なしが保証されます)
--   6. 生成器と縮小の妥当性は、必ずプロパティで確かめる
--
--   この Example を書いたときにも、実際 6 で1つバグが見つかりました。
--   attendees の縮小に shrink をそのまま使ったため、
--   "alice" が "" まで縮んでしまい、prop_bookingShrinkValid が落ちました。
--   shrinkList (const []) に直して解決しています。
--   「テストのテスト」は本当に効きます。
--
-- なお、最後の prop_addIdempotentWhenOverlapping だけは (==>) を使っています。
-- 「空でないスケジュール」という条件で、捨てる数はごくわずかです。
-- こういう使い方なら問題ありません (Example 69)。
