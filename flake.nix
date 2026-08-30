{
  description = "PI Web + Paseo application runtime";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    paseo.url = "github:getpaseo/paseo";
  };

  outputs =
    inputs@{
      nixpkgs,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      packages = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          container = pkgs.callPackage ./nix/runtime.nix {
            inherit inputs system;
          };
        in
        {
          inherit (container) runtimeEnv setup;
        }
      );
    };
}
