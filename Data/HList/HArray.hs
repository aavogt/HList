{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
{-# LANGUAGE MultiParamTypeClasses, FunctionalDependencies, FlexibleInstances,
  FlexibleContexts, UndecidableInstances #-}

{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}

{- |
   The HList library

   (C) 2004, Oleg Kiselyov, Ralf Laemmel, Keean Schupke

   Array-like access to HLists.
 -}

module Data.HList.HArray where

import Data.HList.FakePrelude
import Data.HList.HListPrelude


-- --------------------------------------------------------------------------
-- * Lookup

class HLookupByHNat (n :: HNat) (l :: [*]) where
  type HLookupByHNatR (n :: HNat) (l :: [*]) :: *
  hLookupByHNat :: Proxy n -> HList l -> HLookupByHNatR n l

instance HLookupByHNat HZero (e ': l) where
  type HLookupByHNatR HZero (e ': l) = e
  hLookupByHNat _ (HCons e _)        = e

instance HLookupByHNat n l => HLookupByHNat (HSucc n) (e ': l) where
  type HLookupByHNatR (HSucc n) (e ': l) = HLookupByHNatR n l
  hLookupByHNat n (HCons _ l) = hLookupByHNat (hPred n) l


-- --------------------------------------------------------------------------
-- * Delete

class HDeleteAtHNat (n :: HNat) (l :: [*]) where
  type HDeleteAtHNatR (n :: HNat) (l :: [*]) :: [*]
  hDeleteAtHNat :: Proxy n -> HList l -> HList (HDeleteAtHNatR n l)

instance HDeleteAtHNat HZero (e ': l) where
  type HDeleteAtHNatR  HZero (e ': l) = l
  hDeleteAtHNat _ (HCons _ l)         = l

instance HDeleteAtHNat n l => HDeleteAtHNat (HSucc n) (e ': l) where
  type HDeleteAtHNatR  (HSucc n) (e ': l) = e ': (HDeleteAtHNatR n l)
  hDeleteAtHNat n (HCons e l) = HCons e (hDeleteAtHNat (hPred n) l)


-- --------------------------------------------------------------------------
-- * Update

class HUpdateAtHNat (n :: HNat) e (l :: [*]) where
  type HUpdateAtHNatR (n :: HNat) e (l :: [*]) :: [*]
  hUpdateAtHNat :: Proxy n -> e -> HList l -> HList (HUpdateAtHNatR n e l)

instance HUpdateAtHNat HZero e1 (e ': l) where
  type HUpdateAtHNatR HZero e1 (e ': l) = e1 ': l
  hUpdateAtHNat _ e1 (HCons _ l) = HCons e1 l

instance HUpdateAtHNat n e1 l => HUpdateAtHNat (HSucc n) e1 (e ': l) where
  type HUpdateAtHNatR  (HSucc n) e1 (e ': l) = e ': (HUpdateAtHNatR n e1 l)
  hUpdateAtHNat n e1 (HCons e l) = HCons e (hUpdateAtHNat (hPred n) e1 l)


-- --------------------------------------------------------------------------
-- * Splitting
-- | Splitting an array according to indices
--
-- Signature is inferred:
--
--  > hSplitByHNats :: (HSplitByHNats' ns l' l'1 l'', HMap (HAddTag HTrue) l l') =>
--  >               ns -> l -> (l'1, l'')
{-
hSplitByHNats ns l = hSplitByHNats' ns (hFlag l)

class HNats ns => HSplitByHNats' ns l l' l'' | ns l -> l' l''
 where
  hSplitByHNats' :: ns -> l -> (l',l'')

instance HSplit l l' l''
      => HSplitByHNats' HNil l HNil l'
 where
  hSplitByHNats' HNil l = (HNil,l')
   where
    (l',_) = hSplit l

instance ( HLookupByHNat n l (e,b)
         , HUpdateAtHNat n (e,HFalse) l l'''
         , HSplitByHNats' ns l''' l' l''
         )
      =>   HSplitByHNats' (HCons n ns) l (HCons e l') l''
 where
  hSplitByHNats' (HCons n ns) l = (HCons e l',l'')
   where
    (e,_)    = hLookupByHNat  n l
    l'''     = hUpdateAtHNat  n (e,hFalse) l
    (l',l'') = hSplitByHNats' ns l'''
-}


-- --------------------------------------------------------------------------
-- * Projection


-- One way of implementing it:

hProjectByHNats' ns l = hMap (FHLookupByHNat l) ns

newtype FHLookupByHNat (l :: [*]) = FHLookupByHNat (HList l)

instance HLookupByHNat n l => 
    Apply (FHLookupByHNat l) (Proxy (n :: HNat)) where
  type ApplyR (FHLookupByHNat l) (Proxy n) = HLookupByHNatR n l
  apply (FHLookupByHNat l) n               = hLookupByHNat  n l

-- The drawback is that the list ns must be a constructed value.
-- We cannot lazily pattern-match on GADTs. 

hProjectByHNats (_ :: Proxy (ns :: [HNat])) l = 
    hUnfold (FHUProj :: FHUProj True ns) (l,hZero)

data FHUProj (sel :: Bool) (ns :: [HNat]) = FHUProj


instance Apply (FHUProj sel ns) (HList '[],n) where
    type ApplyR (FHUProj sel ns) (HList '[],n) = HNothing
    apply _ _ = HNothing

instance (ch ~ Proxy (HBoolEQ sel (KMember n ns)), 
	  Apply (ch, FHUProj sel ns) (HList (e ': l),Proxy (n :: HNat))) =>
    Apply (FHUProj sel ns) (HList (e ': l),Proxy (n :: HNat)) where
    type ApplyR (FHUProj sel ns) (HList (e ': l),Proxy n) = 
       ApplyR (Proxy (HBoolEQ sel (KMember n ns)), FHUProj sel ns)
	      (HList (e ': l),Proxy n)
    apply fn s = apply (undefined::ch,fn) s

instance Apply (Proxy True, FHUProj sel ns) 
               (HList (e ': l),Proxy (n::HNat)) where
    type ApplyR (Proxy True, FHUProj sel ns) (HList (e ': l),Proxy n) = 
	(HJust (e, (HList l,Proxy (HSucc n))))
    apply (_,fn) (HCons e l,n) = (HJust (e,(l,hSucc n)))

instance (Apply (FHUProj sel ns) (HList l, Proxy (HSucc n))) =>
    Apply (Proxy False, FHUProj sel ns) 
          (HList (e ': l),Proxy (n::HNat)) where
    type ApplyR (Proxy False, FHUProj sel ns) (HList (e ': l),Proxy n) = 
	ApplyR (FHUProj sel ns) (HList l, Proxy (HSucc n))
    apply (_,fn) (HCons _ l,n) = apply fn (l,hSucc n)


-- lifted member on naturals
type family KMember (n :: HNat) (ns :: [HNat]) :: Bool
type instance KMember n '[]       = False
type instance KMember n (n1 ': l) = HOr (HNatEq n n1) (KMember n l)



-- --------------------------------------------------------------------------
-- * Complement of Projection

-- The naive approach is repeated deletion (which is a bit subtle
-- sine we need to adjust indices)
-- Instead, we compute the complement of indices to project away
-- to obtain the indices to project to, and then use hProjectByHNats.
-- Only the latter requires run-time computation. The rest
-- are done at compile-time only. 

hProjectAwayByHNats (_ :: Proxy (ns :: [HNat])) l = 
    hUnfold (FHUProj :: FHUProj False ns) (l,hZero)

{-
class HProjectAwayByHNats ns l l' | ns l -> l'
 where
  hProjectAwayByHNats :: ns -> l -> l'

instance ( HLength l len
         , HBetween len nats
         , HDiff nats ns ns'
         , HProjectByHNats ns' l l'
         )
           => HProjectAwayByHNats ns l l'
 where
  hProjectAwayByHNats ns l = l'
   where
    len  = hLength l
    nats = hBetween len
    ns'  = hDiff nats ns
    l'   = hProjectByHNats ns' l
-}

{-

-- --------------------------------------------------------------------------
-- * Enumerate naturals
-- | from 1 to x - 1

class HBetween x y | x -> y
 where
  hBetween :: x -> y

instance HBetween (HSucc HZero) (HCons HZero HNil)
 where
  hBetween _ = HCons hZero HNil

instance ( HNat x
         , HBetween (HSucc x) y
         , HAppend y (HCons (HSucc x) HNil) z
         , HList y
         )
           => HBetween (HSucc (HSucc x)) z
 where
  hBetween x = hBetween (hPred x) `hAppend` HCons (hPred x) HNil


-- * Set-difference on naturals

class HDiff x y z | x y -> z
 where
  hDiff :: x -> y -> z

instance HDiff HNil x HNil
 where
  hDiff _ _ = HNil

instance ( HOrdMember e y b
         , HDiff x y z
         , HCond b z (HCons e z) z'
         )
           => HDiff (HCons e x) y z'
 where
  hDiff (HCons e x) y = z'
   where z' = hCond b z (HCons e z)
         b  = hOrdMember e y
         z  = hDiff x y


-- * Membership test for types with 'HOrd' instances
-- |
-- This special type equality/comparison is entirely pure!

class HOrdMember e l b | e l -> b
 where
  hOrdMember :: e -> l -> b

instance HOrdMember e HNil HFalse
 where
  hOrdMember _ _ = hFalse

instance ( HEq e e' b1
         , HOrdMember e l b2
         , HOr b1 b2 b
         )
           => HOrdMember e (HCons e' l) b
 where
  hOrdMember e (HCons e' l) = hOr b1 b2
   where
    b1 = hEq e e'
    b2 = hOrdMember e l


-- --------------------------------------------------------------------------
-- * Length

class (HList l, HNat n) => HLength l n | l -> n
instance HLength HNil HZero
instance (HLength l n, HNat n, HList l)
      => HLength (HCons a l) (HSucc n)

hLength   :: HLength l n => l -> n
hLength _ =  undefined


-- --------------------------------------------------------------------------
-- * Bounded lists

class HMaxLength l s
instance (HLength l s', HLt s' (HSucc s) HTrue) => HMaxLength l s

class HMinLength l s
instance (HLength l s', HLt s (HSucc s') HTrue) => HMinLength l s

class HSingleton l
instance HLength l (HSucc HZero) => HSingleton l

hSingle :: (HSingleton l, HHead l e) => l -> e
hSingle = hHead

-}
