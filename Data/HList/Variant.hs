

{- |
   The HList library

   (C) 2004, Oleg Kiselyov, Ralf Laemmel, Keean Schupke

   Variants, i.e., labelled sums.

   One approach to their implementation would be to consider both
   the favoured label and the corresponding value as dynamics upon
   variant construction. Since we are too lazy to programme some
   Typeable instances for non-ghc systems (NB: in GHC, Typeable
   is derivable), we rather model variants as (opaque) records
   with maybies for the values. Only one value will actually hold
   non-Nothing, as guaranteed by the constructor.

   See VariantP.hs for a different approach to open sums.
-}

module Data.HList.Variant (
   Variant(..),
   toVariant,
   mkVariant,
   unVariant,

   hMapV,
   HMapV(..),

   -- * internal
   HToProxy(..),
   hMaybied,
   HMaybeF(..),

   HPrism(hPrism),
  ) where

import Data.HList.FakePrelude
import Data.HList.Record
import Data.HList.RecordPuns -- for doctest
import Data.HList.HList
import Data.HList.HArray

import Control.Applicative
import Data.Profunctor

{- | Make a @Prism (Variant s) (Variant t) a b@ out of a Label.

See "Data.HList.Labelable".'hLens'' is a more overloaded version.

`s` and `t` have the same labels in the same order: to get \"t\" the \"a\"
in \"s\" is replaced with \"b\".

-}
class (Choice p, Applicative f, SameLength s t)
        => HPrism l p f s t a b where
    hPrism :: Label l -> p a (f b) -> p (Variant s) (f (Variant t))

instance (
    ConvHList proxyT,
    HMapCxt HMaybeF proxyT t,
    {- XXX this (Maybe a) cannot unify with the () used in the
       instance Fail (FieldNotFound l) => HasField l r (),
       so the compile failure when you try to access a field
       is `no instance for (HasField "w" (Record '[]) (Maybe ()))`,
       which is not as pretty as the Fail (FieldNotFound "w') => ...
    -}
    HasField l (Record s) (Maybe a),
    HTPupdateAtLabel l (Maybe b) t,
    HUpdateAtLabel l (Maybe b) s t,

    -- labels in the HList are not changed at all:
    -- number, ordering, actual values are all constant
    SameLength s t,
    HMapCxt (HFmap (Fun '[] ())) s s_,
    HMapCxt (HFmap (Fun '[] ())) t t_,
    s_ ~ t_,

    -- only the target of the prism can have it's type changed
    H2ProjectByLabels '[Label l] s si so,
    H2ProjectByLabels '[Label l] t ti to,
    so ~ to,
    Choice p,
    Applicative f
   ) => HPrism l p f s t a b where
    hPrism l = prism (\b -> toV $ hUpdateAtLabel l (Just b) t)
                  (\s -> case unVariant l s of
                    Just a -> Right a
                    Nothing -> Left $ toV $ hUpdateAtLabel l Nothing (toR s))
      where
        t :: Record t
        t = Record $ hMaybied (unPrime (error "hPrism") :: HList proxyT)
        toV (Record a) = Variant a
        toR (Variant a) = Record a

        prism bt seta = dimap seta (either pure (fmap bt)) . right'




-- --------------------------------------------------------------------------
-- | Variant types on the basis of label-maybe pairs.

newtype Variant mr = Variant (HList mr)



{- | convert a Record that contains actual values into one suitable for 'mkVariant'

>>> let v = toVariant (undefined :: Record [Tagged "x" Int, Tagged "y" Char])
>>> :t v
v :: Record '[Tagged "x" (Proxy Int), Tagged "y" (Proxy Char)]


>>> :set -XQuasiQuotes
>>> let x = 1; y = 'c'; v2 = toVariant [pun| x y |]
>>> :t v2
v2
  :: Num v => Record '[Tagged "x" (Proxy v), Tagged "y" (Proxy Char)]


-}
toVariant (Record a) = Record (hMap (HFmap HToProxy) a)

{- |
>>> :t applyAB HToProxy 'x'
applyAB HToProxy 'x' :: Proxy Char
-}
data HToProxy = HToProxy

instance (b ~ Proxy a) => ApplyAB HToProxy a b where
    applyAB _ _ = Proxy


-- --------------------------------------------------------------------------
-- | Turn proxy sequence into sequence of Nothings

data HMaybeF = HMaybeF
instance ((Tagged l (Proxy t) ~ a, b ~ Tagged l (Maybe t))) =>  ApplyAB HMaybeF a b   where
    applyAB _ _ = Tagged Nothing

hMaybied x = hMap HMaybeF x


-- --------------------------------------------------------------------------
-- | Public constructor
mkVariant x y (Record v) =
    case hTPupdateAtLabel x (Just y) $ Record (hMaybied v) of
    Record t -> Variant t

-- --------------------------------------------------------------------------
-- | Public destructor. 'hPrism' and 'hLens'' can do the same thing.
unVariant x (Variant v) = hLookupByLabel x (Record v)



-- --------------------------------------------------------------------------
-- | Variants are opaque

instance Show (Variant v)
 where
  show _ = "<Cannot show Variant content!>"


-- | apply a function to all tags of the variant
hMapV f v = applyAB (HMapV f) v

newtype HMapV f = HMapV f

instance (x ~ Variant x',
          y ~ Variant y',
          HMapCxt (HFmap (HFmap f)) x' y')
     => ApplyAB (HMapV f) x y where
    applyAB (HMapV f) (Variant x) = Variant $ hMap (HFmap (HFmap f)) x
