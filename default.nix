(import <nixpkgs> { }).callPackage ./package.nix {
  eink-friendly-launcher-src = builtins.fetchGit ./.;
}
