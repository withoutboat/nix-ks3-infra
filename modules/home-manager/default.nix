{ lib, ... }:

{
  imports = [
    ./tools.nix
    (lib.mkAliasOptionModule [ "programs" "ks3-infra" ] [ "programs" "k3s-infra" ])
  ];
}
