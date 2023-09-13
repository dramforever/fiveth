{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      eachSystem = nixpkgs.lib.genAttrs [ "x86_64-linux" ];
    in {
      devShell = eachSystem (system:
        import ./shell.nix {
          pkgs = nixpkgs.legacyPackages.${system};
        });
    };
}
