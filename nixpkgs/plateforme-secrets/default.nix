{
  lib,
  stdenv,
  ssh-to-age,
}:

stdenv.mkDerivation {
  pname = "plateforme-secrets";
  version = "0.2.0";

  # Package sources live beside this file (init-sops.sh, link-secrets.sh).
  # Fileset keeps the rebuild scope to exactly the two scripts, so editing
  # default.nix itself doesn't invalidate the derivation output.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./init-sops.sh
      ./link-secrets.sh
    ];
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m 0755 init-sops.sh $out/bin/init-sops
    install -m 0755 link-secrets.sh $out/bin/link-secrets

    # init-sops must be SOURCED (it exports env vars), so we cannot use
    # makeWrapper (its `exec` would replace the parent shell). Instead we
    # rewrite the bare `ssh-to-age` name to the full store path.
    substituteInPlace $out/bin/init-sops \
      --replace 'ssh-to-age' '${ssh-to-age}/bin/ssh-to-age'

    runHook postInstall
  '';

  meta = {
    description = "Dev shell helpers: SOPS age env init + ../secrets symlink";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
