import ./module.nix ({ lib, ... }:
{ serviceEnabled, name, description, serviceConfig }:

{
  systemd.user.services.${name} = lib.attrsets.optionalAttrs serviceEnabled {
    inherit description serviceConfig;
    wantedBy = [ "default.target" ];
  };
})
