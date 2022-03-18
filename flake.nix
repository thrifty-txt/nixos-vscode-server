{
    description = "VSCode Server support for NixOS";

    inputs = {
        nixpkgs.url = "nixpkgs/nixos-unstable";
    };

    outputs = inputs @ { self, nixpkgs, ... }:
    {
        nixosModules = {
            nixos-vscode-server = import ./modules/vscode-server/module.nix;
            home-manager.nixos-vscode-server = import ./modules/vscode-server/home.nix;
        };
        nixosModule = self.nixosModules.nixos-vscode-server;
    };
}
