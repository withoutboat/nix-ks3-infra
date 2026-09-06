{ lib, ... }:

{
  imports = [
    ./k3s.nix
    (lib.mkAliasOptionModule [ "services" "ks3-infra" ] [ "services" "k3s-infra" ])
  ];
}
