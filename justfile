default:
    @just --list

format:
    nix fmt -- --ci
    stylua --check .
    git ls-files -z | xargs -0 biome check

lint:
    git ls-files '*.lua' | xargs selene --display-style quiet
    lua-language-server --check . --configpath "$(pwd)/.luarc.json" --checklevel=Warning

test:
    busted
    nix build --accept-flake-config .#luarocks-tag-release-action

ci: format lint test
    @:
