{
    description = "Visual Studio Code Server module for HomeManager";

    inputs = {
        nixpkgs.url = "nixpkgs/nixos-unstable";
    };

    outputs = inputs @ { self, nixpkgs, ... }:
    {
        nixosModules.home-manager.nixos-vscode-server = import ./modules/services/vscode-server.nix;
    };
}
