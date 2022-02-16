import ./module.nix ({ lib, ... }:
{ serviceEnabled, name, description, serviceConfig, extensions }:

{
  systemd.user.services.${name} = lib.attrsets.optionalAttrs serviceEnabled ({
    Unit = {
      Description = description;
    };

    Service = serviceConfig;

    Install = {
      WantedBy = [ "default.target" ];
    };
  });

  home.file = extensions;
})
