{
  description = "A Nix-flake-based R development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.rNvim = {
    url = "github:R-nvim/R.nvim";
    flake = false;
  };

  inputs.rnaturalearthhires = {
    url = "github:ropensci/rnaturalearthhires";
    flake = false;
  };

  inputs.ggpmthemes = {
    url = "github:PMassicotte/ggpmthemes";
    flake = false;
  };

  outputs =
    { self, ... }@inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import inputs.nixpkgs {
              inherit system;
              config.allowBroken = true;
              overlays = [ inputs.self.overlays.default ];
            };
          }
        );
    in
    {
      overlays.default = final: prev: rec {
        # Build nvimcom manually from R.nvim source
        nvimcom = final.rPackages.buildRPackage {
          name = "nvimcom";
          src = inputs.rNvim;
          sourceRoot = "source/nvimcom";

          buildInputs = with final; [
            R
            gcc
            gnumake
          ];

          meta = {
            description = "R.nvim communication package";
            homepage = "https://github.com/R-nvim/R.nvim";
            maintainers = [ ];
          };
        };

        # Build rnaturalearthhires from ropensci source
        rnaturalearthhires = final.rPackages.buildRPackage {
          name = "rnaturalearthhires";
          src = inputs.rnaturalearthhires;

          propagatedBuildInputs = with final.rPackages; [
            sp
          ];

          meta = {
            description = "High resolution world vector map data from Natural Earth";
            homepage = "https://github.com/ropensci/rnaturalearthhires";
            maintainers = [ ];
          };
        };

        # Build ggpmthemes from PMassicotte source
        ggpmthemes = final.rPackages.buildRPackage {
          name = "ggpmthemes";
          src = inputs.ggpmthemes;

          propagatedBuildInputs = with final.rPackages; [
            ggplot2
            extrafont
          ];

          meta = {
            description = "Personal ggplot2 themes by Philippe Massicotte";
            homepage = "https://github.com/PMassicotte/ggpmthemes";
            maintainers = [ ];
          };
        };

        # Shared R package list for both wrappers
        rPackageList = with final.rPackages; [
          cli
          cyclocomp
          fs
          ggpmthemes
          ggthemes
          glue
          gt
          here
          httpgd
          janitor
          knitr
          languageserver
          lintr
          magick
          nvimcom
          patchwork
          pins
          quarto
          readxl
          rnaturalearthdata
          rnaturalearthhires
          scales
          sf
          stars
          tidytext
          tidyverse
        ];

        # Create rWrapper with packages (for LSP and R.nvim)
        wrappedR = final.rWrapper.override { packages = rPackageList; };

        # Create radianWrapper with same packages (for interactive use)
        wrappedRadian = final.radianWrapper.override { packages = rPackageList; };
      };

      devShells = forEachSupportedSystem (
        { pkgs }:
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              imagemagick
              quarto
              wrappedR # R with packages for LSP
              wrappedRadian # radian with packages for interactive use
            ];

            env.QUARTO_R = "${pkgs.wrappedR}/bin/R";
          };
        }
      );

      templates = {
        default = {
          path = ./.;
          description = "R development environment with nvimcom and R.nvim integration";
          welcomeText = ''
            # R Nix Development Environment

            ## Getting started
            - Customize R packages in flake.nix rPackageList
            - Enter the shell with `nix develop`

            ## What's included
            - R with languageserver, nvimcom, lintr, fs, and cli
            - radian (modern R console)
            - Configured for R.nvim integration
            - Pre-configured .lintr file with opinionated linting rules

          '';
        };
      };
    };
}
