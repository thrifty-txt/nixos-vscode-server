moduleConfig:
{ lib, pkgs, config, ... }:

with lib;

let
  jsonFormat = pkgs.formats.json { };

  extensionPath = ".vscode-server/extensions";
  settingsPath = ".vscode-server/data/Machine/settings.json";
  
  originalNodePackage = pkgs.nodejs-16_x;

  # Adapted from https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/applications/editors/vscode/generic.nix#L181
  nodePackageFhs = pkgs.buildFHSUserEnv {
    name = originalNodePackage.name;

    # additional libraries which are commonly needed for extensions
    targetPkgs = pkgs: (with pkgs; [
      # ld-linux-x86-64-linux.so.2 and others
      glibc

      # dotnet
      curl
      icu
      libunwind
      libuuid
      openssl
      zlib

      # mono
      krb5
    ]);

    runScript = "${originalNodePackage}/bin/node";

    meta = {
      description = ''
        Wrapped variant of ${name} which launches in an FHS compatible envrionment.
        Should allow for easy usage of extensions without nix-specific modifications.
      '';
    };
  };

  originalNodePackageBin = "${originalNodePackage}/bin/node";
  nodePackageFhsBin = "${nodePackageFhs}/bin/${nodePackageFhs.name}";

  nodeBinToUse = if 
    config.services.vscode-server.useFhsNodeEnvironment
  then 
    nodePackageFhsBin
  else
    originalNodePackageBin;
in
{
  options.services.vscode-server = {
    enable = with types; mkEnableOption "VS Code Server";

    extensions = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.vscode-extensions.bbenoist.nix ]";
      description = ''
        The extensions Visual Studio Code should be started with.
      '';
    };

    immutableExtensionsDir = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether extensions can be installed or updated manually
        by Visual Studio Code.
      '';
    };

    useFhsNodeEnvironment = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Wraps NodeJS in a Fhs compatible envrionment. Should allow for easy usage of extensions without nix-specific modifications. 
      '';
    };

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
  };

  config = moduleConfig { inherit lib; } rec {
    serviceEnabled = config.services.vscode-server.enable;
    name = "auto-fix-vscode-server";
    description = "Automatically fix the VS Code server used by the remote SSH extension";
    serviceConfig = {
      # When a monitored directory is deleted, it will stop being monitored.
      # Even if it is later recreated it will not restart monitoring it.
      # Unfortunately the monitor does not kill itself when it stops monitoring,
      # so rather than creating our own restart mechanism, we leverage systemd to do this for us.
      Restart = "always";
      RestartSec = 0;
      ExecStart = "${pkgs.writeShellScript "${name}.sh" ''
        set -euo pipefail
        PATH=${makeBinPath (with pkgs; [ coreutils findutils inotify-tools ])}
        bin_dir=~/.vscode-server/bin

        # Fix any existing symlinks before we enter the inotify loop.
        if [[ -e $bin_dir ]]; then
          find "$bin_dir" -mindepth 2 -maxdepth 2 -name node -exec ln -sfT ${nodeBinToUse} {} \;
          find "$bin_dir" -path '*/@vscode/ripgrep/bin/rg' -exec ln -sfT ${pkgs.ripgrep}/bin/rg {} \;
        else
          mkdir -p "$bin_dir"
        fi

        while IFS=: read -r bin_dir event; do
          # A new version of the VS Code Server is being created.
          if [[ $event == 'CREATE,ISDIR' ]]; then
            # Create a trigger to know when their node is being created and replace it for our symlink.
            touch "$bin_dir/node"
            inotifywait -qq -e DELETE_SELF "$bin_dir/node"
            ln -sfT ${nodeBinToUse} "$bin_dir/node"
            ln -sfT ${pkgs.ripgrep}/bin/rg "$bin_dir/node_modules/@vscode/ripgrep/bin/rg"
          # The monitored directory is deleted, e.g. when "Uninstall VS Code Server from Host" has been run.
          elif [[ $event == DELETE_SELF ]]; then
            # See the comments above Restart in the service config.
            exit 0
          fi
        done < <(inotifywait -q -m -e CREATE,ISDIR -e DELETE_SELF --format '%w%f:%e' "$bin_dir")
      ''}";
    };

    # Adapted from https://github.com/nix-community/home-manager/blob/master/modules/programs/vscode.nix
    files = mkMerge [
      # Extensions
      (mkIf (config.services.vscode-server.extensions != [ ]) (
      let
        combinedExtensionsDrv = pkgs.buildEnv {
          name = "vscode-extensions";
          paths = config.services.vscode-server.extensions;
        };

        extensionsFolder = "${combinedExtensionsDrv}/share/vscode/extensions";

        addSymlinkToExtension = k: {
          "${extensionPath}/${k}".source = "${extensionsFolder}/${k}";
        };

        extensions = builtins.attrNames (builtins.readDir extensionsFolder);

      in
        if config.services.vscode-server.immutableExtensionsDir then {
          "${extensionPath}".source = extensionsFolder;
      } else
        mkMerge (map addSymlinkToExtension extensions)
      ))

      # Settings
      (mkIf (config.services.vscode-server.settings != { }) {
        "${settingsPath}".source = jsonFormat.generate "vscode-settings" config.services.vscode-server.settings;
      })
    ];
  };
}
