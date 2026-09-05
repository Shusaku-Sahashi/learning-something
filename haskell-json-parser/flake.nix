{
  description = "Haskell JSON Parser 自作ブートキャンプ の開発環境 (GHC 9.6 + cabal-install)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        # ghc96 tracks the latest 9.6.x release in this nixpkgs input, rather
        # than pinning an exact point-release attribute that disappears the
        # next time nixpkgs drops an older GHC minor version.
        hsPkgs = pkgs.haskell.packages.ghc96;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            hsPkgs.ghc
            pkgs.cabal-install
          ];

          shellHook = ''
            echo "GHC $(ghc --numeric-version) / cabal-install $(cabal --numeric-version)"
          '';
        };
      });
}
