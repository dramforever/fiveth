{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      eachSystem = nixpkgs.lib.genAttrs [ "x86_64-linux" ];
    in {
      devShell = eachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
          pkgs.mkShell.override { stdenv = pkgs.stdenvNoCC; } {
            nativeBuildInputs = [
              pkgs.llvmPackages_latest.clang
              pkgs.llvmPackages_latest.bintools
            ];
            depsBuildBuild = [ pkgs.clang-tools pkgs.qemu ];
            hardeningDisable = [ "all" ];
          });
    };
}
