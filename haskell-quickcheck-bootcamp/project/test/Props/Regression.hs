-- | 回帰テスト。
--
-- QuickCheck が見つけた反例を、そのまま固定のテストとして残します。
--
-- なぜ必要か:
--   * ランダムなので、同じ反例が次も出るとは限らない
--   * シードを固定しても、生成器を変えると別の入力になる
--   * 「一度直したバグが二度と出ない」ことを保証したい
--
-- 書き方:
--   once (specificInput ...) の形で、引数を取らないプロパティにします。
--   コメントに「いつ・どのプロパティで見つかったか」を残してください。
module Props.Regression (group) where

import Bootcamp.Interval
import Bootcamp.Queue
import Bootcamp.Text
import Runner
import Test.QuickCheck

group :: Group
group = Group "Regression"
  [ Prop "queue: pop after pop (#1)"          regr_queuePopPop
  , Prop "text: chunksOf 1 (#2)"              regr_chunksOfOne
  , Prop "text: ellipsis at the boundary (#3)" regr_ellipsisBoundary
  , Prop "text: ensureTrailingNewline \"\" (#4)" regr_newlineEmpty
  , Prop "interval: single point (#5)"        regr_intervalPoint
  , Prop "interval: touching at one end (#6)" regr_intervalTouching
  ]

-- #1 2026-09: prop_commandSequence が [Push 0, Push 0, Pop, Pop] で落ちた。
--    pop が mkQueue を通していなかったため、2回目の pop が Nothing になった。
regr_queuePopPop :: Property
regr_queuePopPop = once $
  let q0 = push (2 :: Int) (push 1 empty)
  in case pop q0 of
       Nothing      -> counterexample "first pop failed" False
       Just (a, q1) ->
         case pop q1 of
           Nothing      -> counterexample "second pop returned Nothing" False
           Just (b, _)  -> (a, b) === (1, 2)

-- #2 2026-09: chunksOf の再帰で drop の量を間違え、n = 1 で無限ループした。
regr_chunksOfOne :: Property
regr_chunksOfOne = once $
  chunksOf 1 [1, 2, 3 :: Int] === [[1], [2], [3]]

-- #3 2026-09: ellipsis が n = 3 のとき "..." を足して長さ 6 を返していた。
regr_ellipsisBoundary :: Property
regr_ellipsisBoundary = once $
  conjoin
    [ counterexample "n=3"  (ellipsis 3 "abcdef" === "abc")
    , counterexample "n=4"  (ellipsis 4 "abcdef" === "a...")
    , counterexample "n=6"  (ellipsis 6 "abcdef" === "abcdef")
    , counterexample "n=0"  (ellipsis 0 "abcdef" === "")
    ]

-- #4 2026-09: 空文字列に対して last を呼んで例外になった。
regr_newlineEmpty :: Property
regr_newlineEmpty = once $
  ensureTrailingNewline "" === "\n"

-- #5 2026-09: 幅 0 の区間 (lo == hi) が contains を満たさなかった。
regr_intervalPoint :: Property
regr_intervalPoint = once $
  let i = mkInterval 5 5
  in conjoin
       [ counterexample "width"    (width i === 0)
       , counterexample "contains" (property (contains 5 i))
       , counterexample "overlaps" (property (overlaps i i))
       ]

-- #6 2026-09: 端が1点だけ接する区間で overlaps が False を返していた。
regr_intervalTouching :: Property
regr_intervalTouching = once $
  let a = mkInterval 0 5
      b = mkInterval 5 10
  in conjoin
       [ counterexample "overlaps"  (property (overlaps a b))
       , counterexample "intersect" (intersect a b === Just (mkInterval 5 5))
       ]
