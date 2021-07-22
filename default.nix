{ sources ? import ./nix/sources.nix { }
, haskellNix ? import sources.haskell-nix { }
, pkgs ? import sources.nixpkgs
    (haskellNix.nixpkgsArgs // {
      overlays = haskellNix.nixpkgsArgs.overlays
        ++ [ (import ./nix/wasmtime.nix) ];
    })
}:
pkgs.pkgsStatic.callPackage
  ({ cmake, haskell-nix, ninja, python3, stdenv, wasmtime, which, zstd }:
    stdenv.mkDerivation rec {
      name = "wasi-sdk";
      src = haskell-nix.haskellLib.cleanGit {
        name = "wasi-sdk-src";
        src = ./.;
      };
      outputs = [ "out" "dist" ];
      phases = [ "unpackPhase" "patchPhase" "buildPhase" "installPhase" ];
      patches = [
        "${src}/nix/wasi-libc.patch"
        "${src}/nix/wasi-sdk.patch"
        "${src}/nix/wasi-sdk-tests.patch"
      ];
      strictDeps = true;
      nativeBuildInputs = [ cmake ninja python3 wasmtime which zstd ];
      buildPhase = ''
        patchShebangs tests ./*.sh

        pushd $(mktemp -d)
        ln -s $(which $STRIP) strip
        export PATH=$PATH:$PWD
        popd

        NINJA_FLAGS=-j$NIX_BUILD_CORES make build strip
      '';
      installPhase = ''
        mv build/install/opt/wasi-sdk $out

        tar -c --sort=name --mtime=0 --owner=0 --group=0 --numeric-owner -C $out . | zstd -T$NIX_BUILD_CORES --ultra -22 -o $dist

        env CC=$out/bin/clang CXX=$out/bin/clang++ HOME=$(mktemp -d) tests/run.sh wasmtime
      '';
      allowedReferences = [];
    })
{ }
