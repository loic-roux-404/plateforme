{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "agent-lsp";
  version = "0.11.2";

  src = fetchFromGitHub {
    owner = "blackwell-systems";
    repo = "agent-lsp";
    rev = "v${version}";
    hash = "sha256-rCri95j3DAcZF7LHOTrkCwlRhQWfEIaaUhCVNiWuVZg=";
  };

  vendorHash = "sha256-JTXCizXm2i4sSWC5Ffo+iMXfNUYIi5aZql0Nj70Yvx4=";

  subPackages = [ "cmd/agent-lsp" ];

  meta = with lib; {
    description = "MCP server that orchestrates language servers into agent-native workflows";
    homepage = "https://github.com/blackwell-systems/agent-lsp";
    license = licenses.mit;
    mainProgram = "agent-lsp";
    platforms = platforms.unix;
  };
}
