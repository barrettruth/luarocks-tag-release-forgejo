{
  description = "Build and upload LuaRocks packages from Git tags";

  nixConfig = {
    extra-substituters = "https://neorocks.cachix.org";
    extra-trusted-public-keys = "neorocks.cachix.org-1:WqMESxmVTOJX7qoBC54TwrMMoVI1xAM+7yFin8NRfwk=";
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (import ./nix/overlay.nix { inherit self; })
          ];
        };

        test-lua = pkgs.luajit.withPackages (
          luaPkgs: with luaPkgs; [
            busted
            dkjson
            luafilesystem
            nlua
          ]
        );

        shell = pkgs.mkShell {
          name = "luarocks-tag-release-devShell";
          packages = with pkgs; [
            biome
            just
            lua-language-server
            luarocks
            neovim
            selene
            stylua
            test-lua
          ];
          shellHook = ''
            export LUA_PATH="lua/?.lua;$LUA_PATH"
          '';
        };

        ciShell = shell.overrideAttrs (_: {
          name = "luarocks-tag-release-ciShell";
        });
      in
      {
        formatter = pkgs.nixfmt-tree;
        packages = {
          default = pkgs.luarocks-tag-release-action;
          inherit (pkgs)
            luarocks-tag-release-action
            ;
        };
        devShells = {
          default = shell;
          ci = ciShell;
        };
        checks = {
          inherit (pkgs)
            luarocks-tag-release-action
            ;
        };
      }
    );
}
