{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE MultiParamTypeClasses, FunctionalDependencies #-}
{-# LANGUAGE FlexibleInstances, FlexibleContexts #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}

{- |
   The HList library

   (C) 2004, Oleg Kiselyov, Ralf Laemmel, Keean Schupke

   Basic declarations for typeful heterogeneous lists.

   Excuse the unstructured haddocks: while there are many declarations here
   some are alternative implementations should be grouped, and the definitions
   here are analgous to many list functions in the "Prelude".
 -}

module Data.HList.HList where

import Data.HList.FakePrelude
import Data.HList.HListPrelude

import Control.Applicative (Applicative, liftA, liftA2, pure)


-- --------------------------------------------------------------------------
-- * Heterogeneous type sequences
-- The easiest way to ensure that sequences can only be formed with Nil
-- and Cons is to use GADTs
-- The kind [*] is list kind (lists lifted to types)

data HList (l::[*]) where
    HNil  :: HList '[]
    HCons :: e -> HList l -> HList (e ': l)

instance Show (HList '[]) where
    show _ = "H[]"

instance (Show e, Show (HList l)) => Show (HList (e ': l)) where
    show (HCons x l) = let 'H':'[':s = show l
		       in "H[" ++ show x ++ 
			          (if s == "]" then s else ", " ++ s)

infixr 2 `HCons`


-- --------------------------------------------------------------------------
-- * Basic list functions

-- | 'head'
hHead :: HList (e ': l) -> e
hHead (HCons x _) = x

-- | 'tail'
hTail :: HList (e ': l) -> HList l
hTail (HCons _ l) = l


instance HExtend e (HList l) where
  type HExtendR e (HList l) = HList (e ': l)
  (.*.) = HCons

instance HAppend (HList l1) (HList l2) where
  type HAppendR (HList l1) (HList l2) = HList (HAppendList l1 l2)
  hAppend = hAppendList

type family HAppendList (l1 :: [*]) (l2 :: [*]) :: [*]
type instance HAppendList '[] l = l
type instance HAppendList (e ': l) l' = e ': HAppendList l l'

-- | the same as 'hAppend'
hAppendList :: HList l1 -> HList l2 -> HList (HAppendList l1 l2)
hAppendList HNil l = l
hAppendList (HCons x l) l' = HCons x (hAppend l l')

-- --------------------------------------------------------------------------

-- ** Alternative append


-- | 'hAppend'' below is implemented using the same idea
append' :: [a] -> [a] -> [a]
append' l l' = foldr (:) l' l

-- | Alternative implementation of 'hAppend'. Demonstrates 'HFoldr'
hAppend' :: (HFoldr FHCons v l r) => HList l -> v -> r
hAppend' l l' = hFoldr FHCons l' l

data FHCons = FHCons

instance ApplyAB FHCons (e,HList l) (HList (e ': l)) where
    type ApplyB FHCons (e,HList l) = Just (HList (e ': l))
    type ApplyA FHCons (HList (e ': l)) = Just (e,HList l)
    applyAB _ (e,l) = HCons e l


-- ** Historical append

{- $

The original HList code is included below. In both cases
we had to program the algorithm twice, at the term and the type levels.

[@The class HAppend@]

> class HAppend l l' l'' | l l' -> l''
>  where
>   hAppend :: l -> l' -> l''
>

[@The instance following the normal append@]

> instance HList l => HAppend HNil l l
>  where
>   hAppend HNil l = l
>
> instance (HList l, HAppend l l' l'')
>       => HAppend (HCons x l) l' (HCons x l'')
>  where
>   hAppend (HCons x l) l' = HCons x (hAppend l l')

-}

-- --------------------------------------------------------------------------
-- * Reversing HLists

-- Append the reversed l1 to l2
type family HRevApp (l1 :: [*]) (l2 :: [*]) :: [*]
type instance HRevApp '[] l = l
type instance HRevApp (e ': l) l' = HRevApp l (e ': l')

hRevApp :: HList l1 -> HList l2 -> HList (HRevApp l1 l2)
hRevApp HNil l = l
hRevApp (HCons x l) l' = hRevApp l (HCons x l')

hReverse l = hRevApp l HNil



-- --------------------------------------------------------------------------

--
-- * A nicer notation for lists
--


-- | List termination
hEnd :: HList l -> HList l
hEnd = id

{- ^
   Note:

        [@x :: HList a@] means: @forall a. x :: HList a@

        [@hEnd x@] means: @exists a. x :: HList a@
-}


-- |  Building lists

hBuild :: (HBuild' '[] r) => r
hBuild =  hBuild' HNil

class HBuild' l r where
    hBuild' :: HList l -> r

instance (l' ~ HRevApp l '[])
      => HBuild' l (HList l') where
  hBuild' l = hReverse l

instance HBuild' (a ': l) r
      => HBuild' l (a->r) where
  hBuild' l x = hBuild' (HCons x l)

-- ** examples
{- $examplesNote

The classes above allow the third (shortest) way to make a list
(containing a,b,c) in this case

> list = a `HCons` b `HCons` c `HCons` HNil
> list = a .*. b .*. c .*. HNil
> list = hEnd $ hBuild a b c

>>> let x = hBuild True in hEnd x
H[True]

>>> let x = hBuild True 'a' in hEnd x
H[True, 'a']

>>> let x = hBuild True 'a' "ok" in hEnd x
H[True, 'a', "ok"]

-}

-- *** historical
{- $hbuild the show instance has since changed, but these uses of
'hBuild'/'hEnd' still work

> HList> let x = hBuild True in hEnd x
> HCons True HNil

> HList> let x = hBuild True 'a' in hEnd x
> HCons True (HCons 'a' HNil)

> HList> let x = hBuild True 'a' "ok" in hEnd x
> HCons True (HCons 'a' (HCons "ok" HNil))

> HList> hEnd (hBuild (Key 42) (Name "Angus") Cow (Price 75.5))
> HCons (Key 42) (HCons (Name "Angus") (HCons Cow (HCons (Price 75.5) HNil)))

> HList> hEnd (hBuild (Key 42) (Name "Angus") Cow (Price 75.5)) == angus
> True

-}

-- --------------------------------------------------------------------------

-- * fold
-- $foldNote  Consume a heterogenous list. GADTs and type-classes mix well


class HFoldr f v (l :: [*]) r | f v l -> r where
    hFoldr :: f -> v -> HList l -> r

instance HFoldr f v '[] v where
    hFoldr       _ v _   = v

-- | uses 'ApplyAB' not 'Apply'
instance (App f (e, r) r', HFoldr f v l r)
    => HFoldr f v (e ': l) r' where
    hFoldr f v (HCons x l)    = app f (x, hFoldr f v l)





-- * unfold
-- $unfoldNote Produce a heterogenous list. Uses the more limited
-- 'Apply' instead of 'App' since that's all that is needed for uses of this
-- function downstream. Those could in principle be re-written.

hUnfold :: (Apply p s, HUnfold' p (ApplyR p s)) => p -> s -> HList (HUnfold p s)
hUnfold p s = hUnfold' p (apply p s)

type HUnfold p s = HUnfoldR p (ApplyR p s)

class HUnfold' p res where
    type HUnfoldR p res :: [*]
    hUnfold' :: p -> res -> HList (HUnfoldR p res)

instance HUnfold' p HNothing where
    type HUnfoldR p HNothing = '[]
    hUnfold' _ _ = HNil

instance (Apply p s, HUnfold' p (ApplyR p s)) => HUnfold' p (HJust (e,s)) where
    type HUnfoldR p (HJust (e,s)) = e ': HUnfold p s
    hUnfold' p (HJust (e,s)) = HCons e (hUnfold p s)



-- --------------------------------------------------------------------------
-- * traversing HLists

-- ** producing HList
-- *** map
-- $mapNote It could be implemented with 'hFoldr', as we show further below

{- |

>>> :set -XNoMonomorphismRestriction
>>> let xs = 1 .*. 'c' .*. HNil
>>> :t hMap (HJust ()) xs
hMap (HJust ()) xs
  :: Num e => HList ((':) * (HJust e) ((':) * (HJust Char) ('[] *)))

-}
hMap :: App (HMap f) a b => f -> a -> b
hMap f xs = app (HMap f) xs

newtype HMap f = HMap f

instance (App f a b, ApplyAB (HMap f) (HList as) (HList bs)) =>
    ApplyAB (HMap f) (HList (a ': as)) (HList (b ': bs)) where
    type ApplyA (HMap f) (HList (b ': bs)) = FmapMaybe HList (SequenceMaybe (MapApplyA f (b ': bs)))
    type ApplyB (HMap f) (HList (a ': as)) = FmapMaybe HList (SequenceMaybe (MapApplyB f (a ': as)))
    applyAB (HMap f) (HCons a as) = HCons (app f a) (applyAB (HMap f) as)

instance ApplyAB (HMap f) (HList '[]) (HList '[]) where
    type ApplyA (HMap f) (HList '[]) = Just (HList '[])
    type ApplyB (HMap f) (HList '[]) = Just (HList '[])
    applyAB (HMap f) x = x

type family MapApplyA f (l :: [*]) :: [Maybe *]
type instance MapApplyA f (x ': xs) = ApplyA f x ': MapApplyA f xs
type instance MapApplyA f '[] = '[]

type family MapApplyB f (l :: [*]) :: [Maybe *]
type instance MapApplyB f (x ': xs) = ApplyB f x ': MapApplyB f xs
type instance MapApplyB f '[] = '[]

type family SequenceMaybe (l :: [Maybe k]) :: Maybe [k]
type instance SequenceMaybe '[] = Just '[]
type instance SequenceMaybe (x ': xs) = LiftMCons x (SequenceMaybe xs)

type family LiftMCons (x :: Maybe k) (xs :: Maybe [k]) :: Maybe [k]
type instance LiftMCons Nothing t = Nothing
type instance LiftMCons t Nothing = Nothing
type instance LiftMCons (Just x) (Just xs) = Just (x ': xs)

type family UnHList a :: [k]
type instance UnHList (HList a) = a

type family FmapMaybe (f :: k1 -> k2) (x :: Maybe k1) :: Maybe k2
type instance FmapMaybe f Nothing = Nothing
type instance FmapMaybe f (Just x) = (Just (f x))

{-
class HMap f (l :: [*]) (r :: [*]) | f l -> r where
  hMap :: f -> HList l -> HList r

instance HMap f '[] '[] where
  hMap       _  _  = HNil

instance (ApplyA f e e', HMap f l l') => HMap f (e ': l) (e' ': l') where
  hMap f (HCons x l)    = applyA f x `HCons` hMap f l
  -}




-- --------------------------------------------------------------------------

-- **** alternative implementation
-- $note currently broken

newtype MapCar f = MapCar f

-- | Same as 'hMap' only a different implementation.
hMapMapCar :: (HFoldr (MapCar f) (HList '[]) l l') =>
    f -> HList l -> l'
hMapMapCar f = hFoldr (MapCar f) HNil

instance App f e e' => ApplyAB (MapCar f) (e,HList l) (HList (e' ': l)) where
    type ApplyA (MapCar f) (HList (e' ': l)) = ApplyAMapCar (ApplyA f e') (HList l)
    type ApplyB (MapCar f) (e,HList l) = ApplyBMapCar (ApplyB f e) l
    applyAB (MapCar f) (e,l) = HCons (app f e) l

type family ApplyAMapCar (a :: Maybe *) b :: Maybe *
type instance ApplyAMapCar Nothing t = Nothing
type instance ApplyAMapCar (Just x) t = Just (x,t)

type family ApplyBMapCar (a :: Maybe *) (b::[*]) :: Maybe *
type instance ApplyBMapCar Nothing b = Nothing
type instance ApplyBMapCar (Just x) xs = Just (HList (x ': xs))


-- --------------------------------------------------------------------------

-- *** @appEndo . mconcat . map Endo@
{- |

>>> let xs = length .*. (+1) .*. (*2) .*. HNil
>>> hComposeList xs "abc"
8


-}
hComposeList fs v0 = let r = hFoldr (undefined :: Comp) (\x -> x `asTypeOf` r) fs v0 in r


-- --------------------------------------------------------------------------

-- *** sequence
{- |
   A heterogeneous version of

   > sequenceA :: (Applicative m) => [m a] -> m [a]

   Only now we operate on heterogeneous lists, where different elements
   may have different types 'a'.
   In the argument list of monadic values (m a_i),
   although a_i may differ, the monad 'm' must be the same for all
   elements. That's why we needed "Data.HList.TypeCastGeneric2" (currently (~)).
   The typechecker will complain
   if we attempt to use hSequence on a HList of monadic values with different
   monads.

   The 'hSequence' problem was posed by Matthias Fischmann
   in his message on the Haskell-Cafe list on Oct 8, 2006

   <http://www.haskell.org/pipermail/haskell-cafe/2006-October/018708.html>

   <http://www.haskell.org/pipermail/haskell-cafe/2006-October/018784.html>
 -}

class Applicative m => HSequence m a b | a -> m b, m b -> a where
    hSequence :: a -> m b
{- ^

[@Maybe@]

>>> hSequence $ Just (1 :: Integer) `HCons` (Just 'c') `HCons` HNil
Just H[1, 'c']

>>> hSequence $  return 1 `HCons` Just  'c' `HCons` HNil
Just H[1, 'c']


[@List@]

>>> hSequence $ [1] `HCons` ['c'] `HCons` HNil
[H[1, 'c']]


-}

instance Applicative m => HSequence m (HList ('[])) (HList ('[])) where
    hSequence _ = pure HNil

instance (m1 ~ m, Applicative m, HSequence m (HList as) (HList bs)) =>
    HSequence m (HList (m1 a ': as)) (HList (a ': bs)) where
    hSequence (HCons a b) = liftA2 HCons a (hSequence b)

data ConsM = ConsM
instance (m1 ~ m, Applicative m) => ApplyAB ConsM (m a, m1 (HList l)) (m (HList (a ': l)))  where
    type ApplyB ConsM (m a, m1 (HList l)) = Just (m (HList (a ': l)))
    type ApplyA ConsM (m (HList (a ': l))) = Just (m a, m (HList l))
    applyAB _ (me,ml) = liftA2 HCons me ml


-- **** alternative implementation

-- | 'hSequence2' is not recommended over 'hSequence' since it possibly doesn't
-- allow inferring argument types from the result types. Otherwise this version
-- should do exactly the same thing.
--
-- The DataKinds version needs a little help to find the type of the
-- return HNil, unlike the original version, which worked just fine as
--
--  > hSequence l = hFoldr ConsM (return HNil) l


hSequence2 :: HSequence2 l f a => HList l -> f a
hSequence2 l =
    let rHNil = pure HNil `asTypeOf` (liftA undefined x)
        x = hFoldr ConsM rHNil l
    in x


-- | abbreviation for the constraint on 'hSequence2'
type HSequence2 l f a = (Applicative f, HFoldr ConsM (f (HList ('[]))) l (f a))


-- --------------------------------------------------------------------------


-- --------------------------------------------------------------------------
-- ** producing homogenous lists

-- *** map (no sequencing)
-- $mapOut This one we implement via hFoldr

newtype Mapcar f = Mapcar f

instance (l ~ [e'], App f e e') => ApplyAB (Mapcar f) (e, l) l where
    type ApplyB (Mapcar f) (e, l) = ApplyBMapcar (ApplyB f e)
    type ApplyA (Mapcar f) l = ApplyAMapcar (ApplyA f l)
    applyAB (Mapcar f) (e, l) = app f e : l

-- is there a cleaner way?
type family ApplyBMapcar (a :: Maybe a) :: Maybe k
type instance ApplyBMapcar Nothing = Nothing
type instance ApplyBMapcar (Just x) = Just [x]

type family ApplyAMapcar (a :: Maybe a) :: Maybe k
type instance ApplyAMapcar Nothing = Nothing
type instance ApplyAMapcar (Just [x]) = Just x


-- A synonym for the complex constraint
type HMapOut f l e = (HFoldr (Mapcar f) [e] l [e])

hMapOut :: forall f e l. HMapOut f l e => f -> HList l -> [e]
hMapOut f l = hFoldr (Mapcar f) ([] :: [e]) l



-- --------------------------------------------------------------------------
-- *** mapM

-- |
--
-- > mapM :: forall b m a. (Monad m) => (a -> m b) -> [a] -> m [b]
--
-- Likewise for mapM_.
--
-- See 'hSequence' if the result list should also be heterogenous.

hMapM   :: (Monad m, HMapOut f l (m e)) => f -> HList l -> [m e]
hMapM f =  hMapOut f

-- | GHC doesn't like its own type.
-- hMapM_  :: forall m a f e. (Monad m, HMapOut f a (m e)) => f -> a -> m ()
-- Without explicit type signature, it's Ok. Sigh.
-- Anyway, Hugs does insist on a better type. So we restrict as follows:
--
hMapM_   :: (Monad m, HMapOut f l (m ())) => f -> HList l -> m ()
hMapM_ f =  sequence_ .  disambiguate . hMapM f
 where
  disambiguate :: [q ()] -> [q ()]
  disambiguate =  id






-- --------------------------------------------------------------------------
-- * Type-level equality for lists ('HEq')

instance HEq '[] '[]      True
instance HEq '[] (e ': l) False
instance HEq (e ': l) '[] False
instance (HEq e1 e2 b1, HEq l1 l2 b2, br ~ HAnd b1 b2)
      => HEq (e1 ': l1) (e2 ': l2) br

-- --------------------------------------------------------------------------
-- * Ensure a list to contain HNats only
-- | We do so constructively, converting the HList whose elements
-- are Proxy HNat to [HNat]. The latter kind is unpopulated and
-- is present only at the type level.

type family HNats (l :: [*]) :: [HNat]
type instance HNats '[] = '[]
type instance HNats (Proxy n ': l) = n ': HNats l

hNats :: HList l -> Proxy (HNats l)
hNats = undefined


-- --------------------------------------------------------------------------
-- * Membership tests

-- | Check to see if an HList contains an element with a given type
-- This is a type-level only test

class HMember e1 (l :: [*]) (b :: Bool) | e1 l -> b
instance HMember e1 '[] False
instance (HEq e1 e b, HMember' b e1 l br) => HMember  e1 (e ': l) br
class HMember' (b0 :: Bool) e1 (l :: [*]) (b :: Bool) | b0 e1 l -> b
instance HMember' True e1 l True
instance (HMember e1 l br) => HMember' False e1 l br

-- The following is a similar type-only membership test
-- It uses the user-supplied curried type equality predicate pred
type family HMemberP pred e1 (l :: [*]) :: Bool
type instance HMemberP pred e1 '[] = False
--type instance HMemberP pred e1 (e ': l) = HMemberP' pred e1 l (ApplyR pred (e1,e))

type family HMemberP' pred e1 (l :: [*]) pb :: Bool
type instance HMemberP' pred e1 l (Proxy True) = True
type instance HMemberP' pred e1 l (Proxy False) = HMemberP pred e1 l
 

hMember :: HMember e l b => e -> HList l -> Proxy b
hMember = undefined

-- ** Another type-level membership test
--
-- | Check to see if an element e occurs in a list l
-- If not, return 'Nothing
-- If the element does occur, return 'Just l1
-- where l1 is a type-level list without e
-- XXX should be poly-kinded
class HMemberM (e1 :: *) (l :: [*]) (r :: Maybe [*]) | e1 l -> r
instance HMemberM e1 '[] 'Nothing
instance (HEq e1 e b, HMemberM1 b e1 (e ': l) res)
      =>  HMemberM e1 (e ': l) res
class HMemberM1 (b::Bool) (e1 :: *) (l :: [*]) (r::Maybe [*]) | b e1 l -> r
instance HMemberM1 True e1 (e ': l) ('Just l)
instance (HMemberM e1 l r, HMemberM2 r e1 (e ': l) res)
    => HMemberM1 False e1 (e ': l) res
class HMemberM2 (b::Maybe [*]) (e1 :: *) (l :: [*]) (r::Maybe [*]) | b e1 l -> r
instance HMemberM2 Nothing e1 l Nothing
instance HMemberM2 (Just l1) e1 (e ': l) (Just (e ': l1))

{-
-- --------------------------------------------------------------------------

-- * Staged equality for lists

instance HStagedEq HNil HNil
 where
  hStagedEq _ _ = True

instance HStagedEq HNil (HCons e l)
 where
  hStagedEq _ _ = False

instance HStagedEq (HCons e l) HNil
 where
  hStagedEq _ _ = False

instance ( TypeEq e e' b
         , HStagedEq l l'
         , HStagedEq' b e e'
         )
      =>   HStagedEq (HCons e l) (HCons e' l')
 where
  hStagedEq (HCons e l) (HCons e' l') = (hStagedEq' b e e') && b'
   where
    b  = typeEq e e'
    b' = hStagedEq l l'

class HStagedEq' b e e'
 where
  hStagedEq' :: b -> e -> e' -> Bool

instance HStagedEq' HFalse e e'
 where
  hStagedEq' _ _ _ = False

instance Eq e => HStagedEq' HTrue e e
 where
  hStagedEq' _ = (==)




-- * Static set property based on HEq
class HSet l
instance HSet HNil
instance (HMember e l HFalse, HSet l) => HSet (HCons e l)
-}

-- * Find an element in a set based on HEq
-- | It is a pure type-level operation
-- XXX should be poly-kinded
class HFind (e :: *) (l :: [*]) (n :: HNat) | e l -> n

instance (HEq e1 e2 b, HFind' b e1 l n) => HFind e1 (e2 ': l) n

class HFind' (b::Bool) (e :: *) (l::[*]) (n::HNat) | b e l -> n
instance HFind' True e l HZero
instance HFind e l n => HFind' False e l (HSucc n)



-- ** Membership test based on type equality

-- | could be an associated type if HEq had one
class HTMember e (l :: [*]) (b :: Bool) | e l -> b
instance HTMember e '[] False
instance (HEq e e' b, HTMember e l b', HOr b b' ~ b'')
      =>  HTMember e (e' ': l) b''

hTMember :: HTMember e l b => e -> HList l -> Proxy b
hTMember _ _ = proxy


-- * Intersection based on HTMember

class HTIntersect l1 l2 l3 | l1 l2 -> l3
 where
  -- | Like 'Data.List.intersect'
  hTIntersect :: HList l1 -> HList l2 -> HList l3

instance HTIntersect '[] l '[]
 where
  hTIntersect _ _ = HNil

instance ( HTMember h l1 b
         , HTIntersectBool b h t l1 l2
         )
         => HTIntersect (h ': t) l1 l2
 where
  hTIntersect (HCons h t) l1 = hTIntersectBool b h t l1
   where
    b = hTMember h l1

class HTIntersectBool (b :: Bool) h t l1 l2 | b h t l1 -> l2
 where
 hTIntersectBool :: Proxy b -> h -> HList t -> HList l1 -> HList l2

instance HTIntersect t l1 l2
      => HTIntersectBool True h t l1 (h ': l2)
 where
  hTIntersectBool _ h t l1 = HCons h (hTIntersect t l1)

instance HTIntersect t l1 l2
      => HTIntersectBool False h t l1 l2
 where
  hTIntersectBool _ _ t l1 = hTIntersect t l1


-- * Turn a heterogeneous list into a homogeneous one

-- | Same as @hMapOut Id@
class HList2List l e
 where
  hList2List :: HList l -> [e]

instance HList2List '[] e
 where
  hList2List HNil = []

instance HList2List l e
      => HList2List (e ': l) e
 where
  hList2List (HCons e l) = e:hList2List l




-- --------------------------------------------------------------------------
-- * With 'HMaybe'

-- ** Turn list in a list of justs
-- | the same as @map Just@
--
-- >>> toHJust (2 .*. 'a' .*. HNil)
-- H[HJust 2, HJust 'a']
--
-- >>> toHJust2 (2 .*. 'a' .*. HNil)
-- H[HJust 2, HJust 'a']

class ToHJust l l' | l -> l', l' -> l
 where
  toHJust :: HList l -> HList l'

instance ToHJust '[] '[]
 where
  toHJust HNil = HNil

instance ToHJust l l' => ToHJust (e ': l) (HJust e ': l')
 where
  toHJust (HCons e l) = HCons (HJust e) (toHJust l)

-- | alternative implementation. The Apply instance is in "Data.HList.FakePrelude".
-- A longer type could be inferred.
-- toHJust2 :: (HMap' (HJust ()) a b) => HList a -> HList b
toHJust2 xs = hMap (HJust ()) xs

-- --------------------------------------------------------------------------
-- ** Extract justs from list of maybes
--
-- >>> let xs = 2 .*. 'a' .*. HNil
-- >>> fromHJust (toHJust xs) == xs
-- True

class FromHJust l
 where
  type FromHJustR l
  fromHJust :: HList l -> HList (FromHJustR l)

instance FromHJust '[]
 where
  type FromHJustR '[] = '[]
  fromHJust HNil = HNil

instance FromHJust l => FromHJust (HNothing ': l)
 where
  type FromHJustR (HNothing ': l) = FromHJustR l
  fromHJust (HCons _ l) = fromHJust l

instance FromHJust l => FromHJust (HJust e ': l)
 where
  type FromHJustR (HJust e ': l) = e ': FromHJustR l
  fromHJust (HCons (HJust e) l) = HCons e (fromHJust l)

-- *** alternative implementation

-- | A longer type could be inferred.
-- fromHJust2 :: (HMap' HFromJust a b) => HList a -> HList b
fromHJust2 xs = hMap HFromJust xs

data HFromJust = HFromJust
instance ApplyAB HFromJust (HJust a) a where
    type ApplyB HFromJust (HJust a) = Just a
    type ApplyA HFromJust a = Just (HJust a)
    applyAB _ (HJust a) = a


-- --------------------------------------------------------------------------
-- * Annotated lists

data HAddTag t = HAddTag t
data HRmTag    = HRmTag

-- hAddTag :: HMap' (HAddTag t) l r => t -> HList l -> HList r
hAddTag t l = hMap (HAddTag t) l

-- hRmTag ::  HMap HRmTag l => HList l -> HList (HMapR HRmTag l)
hRmTag l    = hMap HRmTag l

instance ApplyAB (HAddTag t) e (e,t)
 where
  type ApplyB (HAddTag t) e = Just (e,t)
  type ApplyA (HAddTag t) (e,t) = Just e
  applyAB (HAddTag t) e = (e,t)


instance ApplyAB HRmTag (e,t) e
 where
  type ApplyA HRmTag e = Nothing
  type ApplyB HRmTag (e,t) = Just e
  applyAB _ (e,_) = e


-- | Annotate list with a type-level Boolean
-- hFlag :: HMap' (HAddTag (Proxy True)) l r => HList l -> HList r
hFlag l = hAddTag hTrue l


-- --------------------------------------------------------------------------
-- * Splitting by HTrue and HFalse

-- | Analogus to Data.List.'Data.List.partition' 'snd'
--
-- >>> hSplit $ (2,hTrue) .*. (3,hTrue) .*. (1,hFalse) .*. HNil
-- (H[2, 3],H[1])
--
-- it might make more sense to instead have @LVPair Bool e@
-- instead of @(e, Proxy Bool)@ since the former has the same
-- runtime representation as @e@

class HSplit l
 where
  type HSplitT l
  type HSplitF l
  hSplit :: HList l -> (HList (HSplitT l), HList (HSplitF l))

instance HSplit '[]
 where
  type HSplitT '[] = '[]
  type HSplitF '[] = '[]
  hSplit HNil = (HNil,HNil)

instance HSplit l => HSplit ((e, Proxy True) ': l)
 where

  type HSplitT ((e,Proxy True) ': l) = e ': HSplitT l
  type HSplitF ((e,Proxy True) ': l) = HSplitF l

  hSplit (HCons (e,_) l) = (HCons e l',l'')
   where
    (l',l'') = hSplit l

instance HSplit l => HSplit ((e,Proxy False) ': l)
 where
  type HSplitT ((e,Proxy False) ': l) = HSplitT l
  type HSplitF ((e,Proxy False) ': l) = e ': HSplitF l

  hSplit (HCons (e,_) l) = (l',HCons e l'')
   where
    (l',l'') = hSplit l

{-

Let expansion makes a difference to Hugs:

HListPrelude> let x = (hFlag (HCons "1" HNil)) in hSplit x
(HCons "1" HNil,HNil)
HListPrelude> hSplit (hFlag (HCons "1" HNil))
ERROR - Unresolved overloading
*** Type       : HSplit (HCons ([Char],HTrue) HNil) a b => (a,b)
*** Expression : hSplit (hFlag (HCons "1" HNil))


-}