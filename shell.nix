{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell.override { stdenv = pkgs.stdenvNoCC; } {
  nativeBuildInputs = [
    pkgs.pkgsCross.riscv32.stdenv.cc
    pkgs.pkgsCross.riscv64.stdenv.cc
    pkgs.llvmPackages_latest.clang
    pkgs.llvmPackages_latest.bintools
  ];
  depsBuildBuild = [ pkgs.clang-tools pkgs.qemu ];
  hardeningDisable = [ "all" ];
}
