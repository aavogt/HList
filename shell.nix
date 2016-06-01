{ nixpkgs ? import <nixpkgs> {}, compiler ? "default" }:

let

  inherit (nixpkgs) pkgs;

  f = { mkDerivation, array, base, base-orphans, cabal-install, cmdargs
      , directory, filepath, ghc-prim, hspec, lens, mtl, process
      , profunctors, QuickCheck, stdenv, syb, tagged, template-haskell
      }:
      mkDerivation {
        pname = "HList";
        version = "0.4.2.0";
        sha256 = "./.";
        libraryHaskellDepends = [
          array base base-orphans ghc-prim mtl profunctors tagged
          template-haskell
        ];
        testHaskellDepends = [
          array base cmdargs directory filepath hspec lens mtl process
          QuickCheck syb template-haskell
        ];
        buildTools = [ cabal-install ];
        description = "Heterogeneous lists";
        license = stdenv.lib.licenses.mit;
      };

  haskellPackages = if compiler == "default"
                       then pkgs.haskellPackages
                       else pkgs.haskell.packages.${compiler};

  drv = haskellPackages.callPackage f {};

in

  if pkgs.lib.inNixShell then drv.env else drv
