{ lib, ... }:

{
  imports = [
    ./tools.nix
    ./service.nix
    (lib.mkAliasOptionModule [ "programs" "ks3-infra" ] [ "programs" "k3s-infra" ])
    (lib.mkAliasOptionModule [ "services" "ks3-infra" ] [ "services" "k3s-infra" ])
  ];
}
