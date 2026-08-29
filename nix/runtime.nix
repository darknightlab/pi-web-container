{
  pkgs,
  inputs,
  system,
}:

let
  nixIndex = inputs.nix-index-database.packages.${system}.nix-index-with-db;

  starshipConfig = (pkgs.formats.toml { }).generate "starship.toml" {
    add_newline = true;
    character = {
      success_symbol = "[\\$](bold green) ";
      error_symbol = "[\\$](bold red) ";
    };
  };

  bashrc = pkgs.writeText "bashrc" ''
    export STARSHIP_CONFIG=/etc/starship.toml
    eval "$(starship init bash)"
    source ${nixIndex}/etc/profile.d/command-not-found.sh
  '';

  profile = pkgs.writeText "profile" ''
    case $- in *i*) . /etc/bashrc ;; esac
  '';

  loginDefs = pkgs.writeText "login.defs" ''
    ENV_PATH PATH=/nix/var/nix/profiles/runtime/bin:/usr/local/bin:/root/.nix-profile/bin:/usr/bin:/bin
    ENV_SUPATH PATH=/nix/var/nix/profiles/runtime/bin:/usr/local/bin:/root/.nix-profile/bin:/usr/bin:/bin
    ALWAYS_SET_PATH yes
  '';

  pam = pkgs.writeText "pam-container" ''
    auth sufficient pam_rootok.so
    account required pam_permit.so
    session required pam_permit.so
  '';

  sudoers = pkgs.writeText "sudoers" ''
    Defaults secure_path="/nix/var/nix/profiles/runtime/bin:/usr/local/bin:/root/.nix-profile/bin:/usr/bin:/bin"
    pi ALL=(ALL:ALL) NOPASSWD: ALL
    root ALL=(ALL:ALL) ALL
  '';

  setup = pkgs.writeShellScriptBin "pi-web-container-setup" ''
    set -eu

    { printf 'pi:x:0:0:PI container user:/home/pi:/nix/var/nix/profiles/runtime/bin/bash\n'; cat /etc/passwd; } > /tmp/passwd
    mv /tmp/passwd /etc/passwd
    { printf 'pi:x:0:\n'; cat /etc/group; } > /tmp/group
    mv /tmp/group /etc/group

    install -Dm644 ${profile} /etc/profile
    install -Dm644 ${bashrc} /etc/bashrc
    install -Dm644 ${loginDefs} /etc/login.defs
    install -Dm644 ${starshipConfig} /etc/starship.toml
    install -Dm644 ${pam} /etc/pam.d/su
    install -Dm644 ${pam} /etc/pam.d/sudo
    install -Dm440 ${sudoers} /etc/sudoers

    rm /bin/sh /usr/bin/env
    rmdir /bin /usr/bin
    ln -s /nix/var/nix/profiles/runtime/bin /usr/bin
    ln -s /nix/var/nix/profiles/runtime/bin /usr/sbin
    ln -s usr/bin /bin
    ln -s usr/sbin /sbin

    mkdir -p -m 700 /home/pi
  '';

  entrypoint = pkgs.runCommand "pi-web-entrypoint" { } ''
    install -Dm755 ${../entrypoint.sh} $out/bin/pi-web-entrypoint
  '';
in
{
  runtimeEnv = pkgs.buildEnv {
    name = "pi-web-container-runtime";
    pathsToLink = [ "/bin" ];
    ignoreCollisions = true;
    paths = with pkgs; [
      bashInteractive
      chromium
      cloudflared
      cmake
      coreutils
      curl
      diffutils
      direnv
      dnsutils
      ethtool
      file
      gawk
      gcc
      gdu
      gh
      git
      gnumake
      gnupg
      gnused
      go
      inetutils
      inputs.nix-index-database.packages.${system}.nix-index-with-db
      (inputs.paseo.packages.${system}.paseo.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          mkdir -p $out/lib/paseo/packages/server/node_modules/node-pty/build
          cp -a node_modules/node-pty/build/Release $out/lib/paseo/packages/server/node_modules/node-pty/build/
        '';
      }))
      iperf3
      iproute2
      jq
      lbzip2
      lsof
      net-tools
      nexttrace
      nixd
      nixfmt
      nodejs_latest
      openssl
      patch
      pi-coding-agent
      pixi
      pkg-config
      procps
      psmisc
      reptyr
      ripgrep
      rsync
      shadow.su
      starship
      sudo
      tcpdump
      texliveFull
      tmux
      unzip
      vim
      wget
      which
      yq-go
    ];
  };

  inherit setup entrypoint;
}
