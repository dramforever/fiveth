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
          pkgs.mkShell {
            nativeBuildInputs = [
              pkgs.pkgsCross.riscv64.stdenv.cc
              pkgs.pkgsCross.riscv32.stdenv.cc
            ];
            depsBuildBuild = [ pkgs.clang-tools pkgs.qemu ];
            hardeningDisable = [ "all" ];
          });
    };
}
