-- | Bootcamp.Interval のプロパティ。
module Props.Interval (group) where

import Bootcamp.Interval
import Gen.Interval
import Runner
import Test.QuickCheck

group :: Group
group = Group "Bootcamp.Interval"
  [ Prop "generator keeps invariant"   prop_genInvariant
  , Prop "shrink keeps invariant"      prop_shrinkInvariant
  , Prop "shrink is smaller"           prop_shrinkSmaller
  , Prop "width >= 0"                  prop_widthNonNegative
  , Prop "contains both ends"          prop_containsEnds
  , Prop "overlaps is symmetric"       prop_overlapsSymmetric
  , Prop "overlaps is reflexive"       prop_overlapsReflexive
  , Prop "intersect iff overlaps"      prop_intersectIffOverlaps
  , Prop "intersect is contained"      prop_intersectContained
  , Prop "hull contains both"          prop_hullContains
  , Prop "hull is associative"         prop_hullAssociative
  , Prop "hull is commutative"         prop_hullCommutative
  , Prop "overlapping pairs overlap"   prop_genOverlapping
  , Prop "disjoint pairs do not"       prop_genDisjoint
  ]

withI :: (Interval -> Property) -> Property
withI = forAllShrink genInterval shrinkInterval

withII :: (Interval -> Interval -> Property) -> Property
withII f = forAllShrink genInterval shrinkInterval $ \a ->
           forAllShrink genInterval shrinkInterval $ \b -> f a b

prop_genInvariant :: Property
prop_genInvariant = withI (property . invariant)

prop_shrinkInvariant :: Property
prop_shrinkInvariant = withI (property . all invariant . shrinkInterval)

prop_shrinkSmaller :: Property
prop_shrinkSmaller = withI (\i -> property (i `notElem` shrinkInterval i))

prop_widthNonNegative :: Property
prop_widthNonNegative = withI (\i -> property (width i >= 0))

prop_containsEnds :: Property
prop_containsEnds = withI (\i -> property (contains (lo i) i && contains (hi i) i))

prop_overlapsSymmetric :: Property
prop_overlapsSymmetric = withII (\a b -> overlaps a b === overlaps b a)

prop_overlapsReflexive :: Property
prop_overlapsReflexive = withI (\i -> property (overlaps i i))

prop_intersectIffOverlaps :: Property
prop_intersectIffOverlaps =
  withII (\a b -> (intersect a b /= Nothing) === overlaps a b)

prop_intersectContained :: Property
prop_intersectContained = withII $ \a b ->
  case intersect a b of
    Nothing -> property True
    Just c  -> counterexample (show (a, b, c)) $
                 property (lo c >= lo a && lo c >= lo b
                             && hi c <= hi a && hi c <= hi b
                             && invariant c)

prop_hullContains :: Property
prop_hullContains = withII $ \a b ->
  let h = hull a b
  in property (lo h <= lo a && lo h <= lo b && hi h >= hi a && hi h >= hi b)

prop_hullAssociative :: Property
prop_hullAssociative =
  forAllShrink genInterval shrinkInterval $ \a ->
  forAllShrink genInterval shrinkInterval $ \b ->
  forAllShrink genInterval shrinkInterval $ \c ->
    hull (hull a b) c === hull a (hull b c)

prop_hullCommutative :: Property
prop_hullCommutative = withII (\a b -> hull a b === hull b a)

prop_genOverlapping :: Property
prop_genOverlapping = forAll genOverlappingPair (uncurry overlaps)

prop_genDisjoint :: Property
prop_genDisjoint = forAll genDisjointPair (\(a, b) -> not (overlaps a b))
