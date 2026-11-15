{
  lib,
  stdenv,
}:

# paas CLI + the example wrapper template it installs (`paas init <dest>`).
# Packaged from example/ — flake path, so git-tracked files only.
stdenv.mkDerivation {
  pname = "paas-cli";
  version = "0.1.0";

  src = ../example;

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    cp -r $src $out
    chmod -R u+w $out
    chmod +x $out/paas

    runHook postInstall
  '';

  meta = {
    description = "paas deployment CLI + example wrapper template (plateforme distribution)";
    mainProgram = "paas";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
