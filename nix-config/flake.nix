{
  description = "richard's NixOS system";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ragenix.url = "github:yaxitech/ragenix";
    nur.url = "github:nix-community/NUR";
  };
  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ragenix, nur, ... }:
  let
    system = "x86_64-linux";
    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit ragenix; };
      modules = [
        ./configuration.nix
        ragenix.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.richard = import ./home.nix;
          home-manager.extraSpecialArgs = { inherit pkgs-unstable; };
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = [ nur.overlays.default ];
        }
      ];
    };
  };
}
