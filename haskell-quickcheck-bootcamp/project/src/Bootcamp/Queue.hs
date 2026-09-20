-- | 2つのリストで実装した償却 O(1) のキュー。
--
-- 表現不変条件: front が空なら back も空。
-- この不変条件があるおかげで、'pop' の先頭要素の取り出しが O(1) になります。
module Bootcamp.Queue
  ( Queue
  , empty
  , push
  , pop
  , size
  , toList
  , fromList
  , invariant
  ) where

data Queue a = Queue [a] [a]
  deriving (Eq)

instance Show a => Show (Queue a) where
  show q = "fromList " ++ show (toList q)

-- | 表現不変条件。テストから参照するため公開しています。
invariant :: Queue a -> Bool
invariant (Queue [] back) = null back
invariant _               = True

-- | 内部コンストラクタ。不変条件を保つのはここだけの責任です。
mkQueue :: [a] -> [a] -> Queue a
mkQueue []    back = Queue (reverse back) []
mkQueue front back = Queue front back

empty :: Queue a
empty = Queue [] []

push :: a -> Queue a -> Queue a
push x (Queue front back) = mkQueue front (x : back)

pop :: Queue a -> Maybe (a, Queue a)
pop (Queue [] _)             = Nothing
pop (Queue (x : front) back) = Just (x, mkQueue front back)

size :: Queue a -> Int
size (Queue front back) = length front + length back

toList :: Queue a -> [a]
toList (Queue front back) = front ++ reverse back

fromList :: [a] -> Queue a
fromList = foldl (flip push) empty
