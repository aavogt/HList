{ mkDerivation, array, base, base-orphans, cmdargs, directory
, filepath, ghc-prim, hspec, lens, mtl, process, profunctors
, QuickCheck, stdenv, syb, tagged, template-haskell
}:
mkDerivation {
  pname = "HList";
  version = "0.4.2.1";
  src = "./.";
  doCheck = false;

  libraryHaskellDepends = [
    array base base-orphans ghc-prim mtl profunctors tagged
    template-haskell
  ];
  testHaskellDepends = [
    array base cmdargs directory filepath hspec lens mtl process
    QuickCheck syb template-haskell
  ];
  description = "Heterogeneous lists";
  license = stdenv.lib.licenses.mit;
}
