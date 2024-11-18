{
  nixConfig = {
    extra-substituters = "https://nixpkgs-ruby.cachix.org";
    extra-trusted-public-keys = "nixpkgs-ruby.cachix.org-1:vrcdi50fTolOxWCZZkw0jakOnUI1T19oYJ+PRYdK4SM=";
  };

  inputs = {
    bob-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    bob-ruby.inputs.nixpkgs.follows = "nixpkgs";
    bundix = {
      url = "github:inscapist/bundix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "nixpkgs";
    pre-commit-hooks-nix.url = "github:cachix/pre-commit-hooks.nix";
    ruby-nix.url = "github:inscapist/ruby-nix";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.pre-commit-hooks-nix.flakeModule
      ];
      perSystem =
        {
          lib,
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = lib.mkForce (
            import inputs.nixpkgs {
              inherit system;
              config.allowUnfree = true;
              overlays = [
                inputs.bob-ruby.overlays.default
              ];
            }
          );
          devShells.default =
            let
              rubyNix = inputs.ruby-nix.lib pkgs;
              gemset = import ./gemset.nix;
              gemConfig = { };
              ruby = pkgs."ruby-3.1.2";
              bundixcli = inputs.bundix.packages.${system}.default;
              bundleLock = pkgs.writeShellScriptBin "bundle-lock" ''
                export BUNDLE_PATH=vendor/bundle
                bundle lock
              '';
              bundleUpdate = pkgs.writeShellScriptBin "bundle-update" ''
                export BUNDLE_PATH=vendor/bundle
                bundle lock --update
              '';
              inherit
                (rubyNix {
                  inherit gemset ruby;
                  name = "basic-rails-app";
                  gemConfig = pkgs.defaultGemConfig // gemConfig;
                })
                env
                ;
            in
            pkgs.mkShell {
              packages = builtins.attrValues {
                inherit
                  env
                  bundixcli
                  bundleLock
                  bundleUpdate
                  ;
                inherit (pkgs) nodejs yarn rufo;
              };
            };
        };
    };
}
