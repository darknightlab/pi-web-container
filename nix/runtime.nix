{
  pkgs,
  inputs,
  system,
}:

let
  sudoers = pkgs.writeText "sudoers" ''
    Defaults secure_path="/nix/var/nix/profiles/runtime/bin:/usr/local/bin:/root/.nix-profile/bin:/usr/bin:/bin"
    pi ALL=(ALL:ALL) NOPASSWD: ALL
    root ALL=(ALL:ALL) ALL
  '';

  setup = pkgs.writeShellScriptBin "pi-web-container-setup" ''
    set -eu

    if ! grep -q '^pi:' /etc/passwd; then
      { printf 'pi:x:0:0:PI container user:/home/pi:/nix/var/nix/profiles/runtime/bin/bash\n'; cat /etc/passwd; } > /tmp/passwd
      mv /tmp/passwd /etc/passwd
    fi
    if ! grep -q '^pi:' /etc/group; then
      { printf 'pi:x:0:\n'; cat /etc/group; } > /tmp/group
      mv /tmp/group /etc/group
    fi

    install -Dm440 ${sudoers} /etc/sudoers
    mkdir -p -m 700 /home/pi
  '';

  paseo = inputs.paseo.packages.${system}.paseo.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      ptyPlatform="$(node -p 'process.platform + "-" + process.arch')"
      target=$out/lib/paseo/packages/server/node_modules/node-pty/prebuilds
      mkdir -p "$target"
      cp -a "packages/server/node_modules/node-pty/prebuilds/$ptyPlatform" "$target/"
    '';
  });
in
{
  runtimeEnv = pkgs.buildEnv {
    name = "pi-web-container-app-runtime";
    pathsToLink = [ "/bin" ];
    ignoreCollisions = true;
    paths = [
      paseo
      pkgs.pi-coding-agent
    ];
  };

  inherit setup;
}
