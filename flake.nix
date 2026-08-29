{
  description = "PI Web + Paseo container runtime";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    paseo.url = "github:getpaseo/paseo";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
          inherit (container) runtimeEnv setup entrypoint;
        }
      );
    };
}
