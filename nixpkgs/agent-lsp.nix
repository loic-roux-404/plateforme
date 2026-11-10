{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "agent-lsp";
  version = "0.24.2";

  src = fetchFromGitHub {
    owner = "blackwell-systems";
    repo = "agent-lsp";
    rev = "v${version}";
    hash = "sha256-WSl3/xlN3Re8eN3sy9Zm49ljI0vrmm0YWTEY/wI7ZKY=";
  };

  vendorHash = "sha256-aBokNk3GGCkMX5UYotiQHzWRKfHF6Tc0EA4hIj5XIKg=";

  subPackages = [ "cmd/agent-lsp" ];

  meta = with lib; {
    description = "MCP server that orchestrates language servers into agent-native workflows";
    homepage = "https://github.com/blackwell-systems/agent-lsp";
    license = licenses.mit;
    mainProgram = "agent-lsp";
    platforms = platforms.unix;
  };
}
