{ config, lib, pkgs, ... }:

with lib;

let
    cfg = config.programs.vscode;

    jsonFormat = pkgs.formats.json { };

    configPath = ".vscode-server";

    extensionsPath = "${configPath}/extensions";
    settingsPath = "${configPath}/data/Machine/settings.json";
in

{
    imports = [
        (mkChangedOptionModule [ "programs" "vscode" "immutableExtensionsDir" ] [
        "programs"
        "vscode"
        "mutableExtensionsDir"
        ] (config: !config.programs.vscode.immutableExtensionsDir))
    ];

    options = {
        services.vscode-server = {
            enable = mkEnableOption "Visual Studio Code Server";

            settings = mkOption {
                type = jsonFormat.type;
                default = { };
                example = literalExpression ''
                {
                    "explorer.compactFolders" = true;
                }
                '';
                description = ''
                Configuration written to Visual Studio Code's
                <filename>settings.json</filename>.
                '';
            };

            extensions = mkOption {
                type = types.listOf types.package;
                default = [ ];
                example = literalExpression "[ pkgs.vscode-extensions.bbenoist.nix ]";
                description = ''
                The extensions Visual Studio Code should be started with.
                '';
            };

            mutableExtensionsDir = mkOption {
                type = types.bool;
                default = true;
                example = false;
                description = ''
                Whether extensions can be installed or updated manually
                or by Visual Studio Code.
                '';
            };
        };
    };

    config = mkIf cfg.enable {
        home.file = mkMerge [
            (mkIf (cfg.settings != { }) {
                "${settingsPath}".source = jsonFormat.generate "vscode-settings" cfg.settings;
            })
            (mkIf (cfg.extensions != [ ]) (
                let
                    combinedExtensionsDrv = pkgs.buildEnv {
                        name = "vscode-extensions";
                        paths = cfg.extensions;
                    };

                    extensionsFolder = "${combinedExtensionsDrv}/share/vscode/extensions";

                    # Adapted from https://discourse.nixos.org/t/vscode-extensions-setup/1801/2
                    addSymlinkToExtension = k: {
                        "${extensionsPath}/${k}".source = "${extensionsFolder}/${k}";
                    };
                    extensions = builtins.attrNames (builtins.readDir extensionsFolder);
                in if cfg.mutableExtensionsDir then
                    mkMerge (map addSymlinkToExtension extensions)
                else {
                    "${extensionsPath}".source = extensionsFolder;
            }))
        ];
    };
}