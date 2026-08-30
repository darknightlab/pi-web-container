import { writeFileSync } from "node:fs";

const [outputPath, paseoValue] = process.argv.slice(2);
if (!outputPath || !["0", "1"].includes(paseoValue)) {
  console.error("Usage: environment.mjs <output-path> <paseo-enabled: 0|1>");
  process.exit(2);
}

const paseoDescription = paseoValue === "1"
  ? "It runs [`pi-web`](https://github.com/canoziia/pi-web) for browser-based Pi sessions and [`paseo`](https://github.com/getpaseo/paseo) for remote and mobile agent orchestration."
  : "It runs [`pi-web`](https://github.com/canoziia/pi-web) for browser-based Pi sessions. Paseo is installed but disabled for this container instance.";

const content = `# Container Environment

You are running inside the [\`pi-web-container\`](https://github.com/darknightlab/pi-web-container) development container. ${paseoDescription}

- This container uses Nix for its runtime environment and development tools.
- The default login name is \`pi\`; \`pi\` and \`root\` share uid 0.
- Use \`$USER\` and \`$HOME\` to distinguish login identities. \`whoami\` always reports \`pi\` because it resolves the first uid-0 entry.
- Persistent user data lives under \`/home\`.
- Use \`su - root\` or \`sudo -i\` when a root login environment is specifically required; this does not change privileges because both names use uid 0.
- Do not directly edit \`$HOME/.pi/agent/environment.md\` or \`$HOME/.pi/agent/AGENTS.md\`; the container entrypoint generates them. Put personal guidance in \`$HOME/.pi/agent/instructions.md\`.

- Use \`nix-shell -p <package>\` to temporarily run required Nix packages.
- Python is not installed globally. Use [Pixi](https://pixi.prefix.dev/) when Python is needed.
`;

writeFileSync(outputPath, content, { encoding: "utf8", mode: 0o600 });
