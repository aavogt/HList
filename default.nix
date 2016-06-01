{ mkDerivation, array, base, base-orphans, cmdargs, directory
, filepath, ghc-prim, hspec, lens, mtl, process, profunctors
, QuickCheck, stdenv, syb, tagged, template-haskell
}:
mkDerivation {
  pname = "HList";
  version = "0.4.2.1";
  sha256 = "15bpglqj33n4y68mg8l2g0rllrcisg2f94wsl3n7rpy43md596fd";
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
