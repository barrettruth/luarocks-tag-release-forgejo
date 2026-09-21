# Contributing

Development, issues, and pull requests happen on
[Forgejo](https://forge.barrettruth.com/barrettruth/luarocks-tag-release-forgejo).

## Scope

luarocks-tag-release-forgejo is a Forgejo Action for publishing LuaRocks
releases from git tags. It is not a general release automation framework,
package manager, or CI runner.

## Pull Requests

Bug fixes and documentation fixes are welcome. AI-generated contributions are
not accepted.

For new behavior, open an issue first unless the change is small and already
fits the project's scope.

Behavior or configuration changes should update `README.md` and action
metadata/docs when appropriate.

## Development

It is preferred to use the Nix development shell, which bundles all necessary
tools:

```sh
nix develop
```

## Checks

Run the local checks before opening a pull request:

```sh
nix develop --accept-flake-config .#ci --command just ci
```
