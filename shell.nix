{ system ? builtins.currentSystem }:
let
  d = import ./. { inherit system; src = ./.; };
in
d.devShells.${system}.default
