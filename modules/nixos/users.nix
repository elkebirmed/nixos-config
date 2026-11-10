# Hosts declare `my.users.<name> = { ... }`. Each user needs ./users/<name>/default.nix
# (a home-manager module). Common home modules from ./modules/home apply to all.
{
  config,
  lib,
  inputs,
  homeModules,
  userModules,
  ...
}:
let
  cfg = config.my.users;
  useSops = config.my.secrets.enable;
in
{
  options.my.users = lib.mkOption {
    default = { };
    description = "Users present on this host.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          admin = lib.mkEnableOption "sudo (wheel group)";
          extraGroups = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          sshKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          persistDirs = lib.mkOption {
            type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
            default = [ ];
            description = "Extra home directories to persist.";
          };
        };
      }
    );
  };

  config = {
    users.users =
      { root.hashedPassword = "!"; }
      // lib.mapAttrs (
        name: u:
        {
          isNormalUser = true;
          extraGroups = [ "networkmanager" ] ++ u.extraGroups ++ lib.optional u.admin "wheel";
          openssh.authorizedKeys.keys = u.sshKeys;
        }
        // (
          if useSops then
            { hashedPasswordFile = config.sops.secrets."passwords/${name}".path; }
          else
            { initialPassword = "changeme"; }
        )
      ) cfg;

    # secrets/common.yaml:
    #   passwords: { mohamed: <hash>, kids: <hash> }
    #   email:     { mohamed: a@b.c,  kids: x@y.z }
    sops.secrets = lib.mkIf useSops (
      lib.mapAttrs' (
        name: _: lib.nameValuePair "passwords/${name}" { neededForUsers = true; }
      ) cfg
      // lib.mapAttrs' (
        name: _: lib.nameValuePair "email/${name}" { owner = name; }
      ) cfg
    );

    # Rendered at activation into /run/secrets/rendered/git-<user>, included by
    # git via modules/home/git.nix. The email never enters the nix store.
    sops.templates = lib.mkIf useSops (
      lib.mapAttrs' (
        name: _:
        lib.nameValuePair "git-${name}" {
          owner = name;
          content = ''
            [user]
              email = ${config.sops.placeholder."email/${name}"}
          '';
        }
      ) cfg
    );

    environment.persistence."/persist".users = lib.mapAttrs (_: u: {
      directories = [
        "Documents"
        "Downloads"
        "Pictures"
        "Videos"
        "Audio"
        "Projects"
        {
          directory = ".ssh";
          mode = "0700";
        }
        {
          directory = ".gnupg";
          mode = "0700";
        }
        {
          directory = ".config/sops";
          mode = "0700";
        }
      ] ++ u.persistDirs;
    }) cfg;

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "bak";
      extraSpecialArgs = { inherit inputs; };
      users = lib.mapAttrs (name: _: {
        imports = homeModules ++ [
          (userModules.${name} or (throw "my.users.${name}: missing users/${name}/default.nix"))
        ];
      }) cfg;
    };
  };
}
