{
  description = "My NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";
  };

  outputs =
    inputs@{ flake-parts, haumea, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      let
        inherit (nixpkgs) lib;
        pathLoader = _inputs: path: path;
        
        collapseDefault = _cursor: dir: dir.default or dir;
        load =
          src:
          haumea.lib.load {
            inherit src;
            loader = pathLoader;
            transformer = [ collapseDefault ];
          };

        modulesIn = src: lib.collect builtins.isPath (load src);

        nixosModules = modulesIn ./modules/nixos; # applied to EVERY host
        homeModules = modulesIn ./modules/home; # applied to EVERY user
        
        hosts = load ./hosts;
        users = load ./users;
      in
      {
        systems = [ "x86_64-linux" ];

        flake.nixosConfigurations = lib.mapAttrs (
          hostName: hostModule:
          nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit inputs homeModules;
              userModules = users;
            };
            
            modules = [
              inputs.disko.nixosModules.disko
              inputs.sops-nix.nixosModules.sops
              inputs.impermanence.nixosModules.impermanence
              inputs.home-manager.nixosModules.home-manager
              { networking.hostName = hostName; }
              hostModule
            ] ++ nixosModules;
          }
        ) hosts;

        perSystem =
          { pkgs, ... }:
          {
            formatter = pkgs.nixfmt-tree;
            devShells.default = pkgs.mkShell {
              packages = with pkgs; [ git sops age ssh-to-age mkpasswd ];
            };
          };
      }
    );
}
