{
  description = "illogical-impulse (dots-hyprland) desktop shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # dots-hyprland's own prior WIP flake (sdata/dist-nix/home-manager/flake.nix)
    # already used the GitHub mirror rather than quickshell's own forge
    # (git.outfoxxed.me, which is what caelestia's flake points at) -- kept
    # consistent with that choice rather than caelestia's.
    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    forAllSystems = fn:
      nixpkgs.lib.genAttrs nixpkgs.lib.platforms.linux (
        system: fn nixpkgs.legacyPackages.${system}
      );
  in {
    formatter = forAllSystems (pkgs: pkgs.alejandra);

    packages = forAllSystems (pkgs: rec {
      illogical-impulse = pkgs.callPackage ./nix {
        quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
          withX11 = false;
          withI3 = false;
        };
      };
      default = illogical-impulse;
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        inputsFrom = [self.packages.${pkgs.stdenv.hostPlatform.system}.illogical-impulse];
        packages = with pkgs; [material-symbols rubik nerd-fonts.jetbrains-mono];
      };
    });

    homeManagerModules.default = import ./nix/hm-module.nix self;
  };
}
