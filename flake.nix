{
  description = "PI WEB portable dev environment (Nix-managed toolchain)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          devEnv = pkgs.buildEnv {
            name = "pi-web-dev-env";
            paths = with pkgs; [
              # PI WEB / node-pty build & runtime toolchain
              coreutils
              gnused
              gnumake
              gcc
              python3
              nodejs_latest
              git

              # Developer tools mirrored from ~/NixOS
              starship
              direnv
              tmux
              reptyr
              go
              nixfmt
              nixd
              pixi
              gdu

              # Everyday CLI utilities
              curl
              wget
              jq
              ripgrep
              fd
              unzip
              vim
            ];
          };
        });
    in
    {
      packages = forAllSystems;
    };
}
