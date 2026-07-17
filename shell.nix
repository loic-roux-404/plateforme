{ system ? builtins.currentSystem }:
let
  d = import ./.;
in
d.devShells.${system}.default
