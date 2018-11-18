{ compiler ? "ghc843"

, doBenchmark ? false
, doTracing   ? false
, doStrict    ? false

, rev     ? "7c1b85cf6de1dc431e5736bff8adf01224e6abe5"
, sha256  ? "1i8nvc4r0zx263ch5k3b6nkg78sc9ggx2d4lzri6kmng315pcs05"
, pkgs    ?
    if builtins.compareVersions builtins.nixVersion "2.0" < 0
    then abort "hnix requires at least nix 2.0"
    else import (builtins.fetchTarball {
           url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
           inherit sha256; }) {
           config.allowUnfree = true;
           config.allowBroken = false;
         }
, returnShellEnv ? pkgs.lib.inNixShell
, mkDerivation ? null
}:

let

haskellPackages = pkgs.haskell.packages.${compiler};

drv = haskellPackages.developPackage {
  root = ./.;

  overrides = with pkgs.haskell.lib; self: super: {
    mono-traversable = dontCheck super.mono-traversable;
  }
  //
  (if compiler == "ghc802"
   then {
     concurrent-output = doJailbreak super.concurrent-output;
   }
   else {})
  //
  (if compiler == "ghcjs" then {} else
   {
     cryptohash-md5    = doJailbreak super.cryptohash-md5;
     cryptohash-sha1   = doJailbreak super.cryptohash-sha1;
     cryptohash-sha256 = doJailbreak super.cryptohash-sha256;
     cryptohash-sha512 = doJailbreak super.cryptohash-sha512;
     serialise         = dontCheck super.serialise;

     ghc-datasize =
       overrideCabal super.ghc-datasize (attrs: {
         enableLibraryProfiling    = false;
         enableExecutableProfiling = false;
       });

     ghc-heap-view =
       overrideCabal super.ghc-heap-view (attrs: {
         enableLibraryProfiling    = false;
         enableExecutableProfiling = false;
       });
   });

  source-overrides =
    if compiler == "ghc802"
    then {
      lens-family-core = "1.2.1";
      lens-family = "1.2.1";
    }
    else {};

  modifier = drv: pkgs.haskell.lib.overrideCabal drv (attrs: {
    buildTools = (attrs.buildTools or []) ++ [
      pkgs.haskell.packages.${compiler}.cabal-install
    ];

    enableLibraryProfiling = false;

    testHaskellDepends = (attrs.testHaskellDepends or []) ++
      [ pkgs.nix

        # Use the same version of hpack no matter what the compiler version
        # is, so that we know exactly what the contents of the generated
        # .cabal file will be. Otherwise, Travis may error out claiming that
        # the cabal file needs to be updated because the result is different
        # that the version we committed to Git.
        pkgs.haskell.packages.ghc843.hpack
        pkgs.haskell.packages.ghc843.criterion
      ];

    inherit doBenchmark;

    configureFlags =
         pkgs.stdenv.lib.optional  doTracing   "--flags=tracing"
      ++ pkgs.stdenv.lib.optional  doStrict    "--ghc-options=-Werror";

    passthru = {
      nixpkgs = pkgs;
    };
  });

  inherit returnShellEnv;
};

in drv
