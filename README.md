# luarocks-tag-release-forgejo

Forgejo-compatible wrapper around
[`nvim-neorocks/luarocks-tag-release`](https://github.com/nvim-neorocks/luarocks-tag-release).

> [!NOTE]
> Due to GitHub's historic unreliability, active development is hosted on
> [Forgejo](https://forge.barrettruth.com/barrettruth/luarocks-tag-release-forgejo).
> GitHub is maintained as a read-only mirror.

This action keeps the upstream Lua publisher implementation, but changes the
parts that are specific to Barrett's Forgejo runners and Forgejo archive
layout:

- exposes the Nix package on `aarch64-linux` as well as `x86_64-linux`;
- assumes Forgejo source archives unpack to `<repo>/`;
- removes the GitHub-only Nix installer step;
- supports explicit LuaRocks verification servers after upload.

## Stable Releases

```yaml
- uses: https://forge.barrettruth.com/barrettruth/luarocks-tag-release-forgejo@v0.2.0
  with:
    license: GPL-3.0
    verification_servers: |
      https://luarocks.org
      https://luarocks.org/manifests/barrettruth
```

## Nightly Releases

```yaml
- name: Compute LuaRocks specrev
  run: echo "LUAROCKS_SPECREV=$(git rev-list --count "$FORGEJO_SHA")" >> "$FORGEJO_ENV"

- uses: https://forge.barrettruth.com/barrettruth/luarocks-tag-release-forgejo@v0.2.0
  with:
    version: scm
    specrev: ${{ env.LUAROCKS_SPECREV }}
    license: GPL-3.0
    verification_servers: |
      https://luarocks.org/manifests/barrettruth
      https://luarocks.org/dev
```

## Notes

Development rocks uploaded to LuaRocks are visible immediately in the uploader
manifest. The global `/dev` manifest can lag or omit freshly uploaded versions,
so workflows should verify against the uploader manifest first.

`extra_luarocks_args` is parsed as newline-separated argv entries and shell
quoted before execution. For LuaRocks flags that take a separate value, put the
flag and value on separate lines or use `--flag=value`.

# Acknowledgements

- [`nvim-neorocks/luarocks-tag-release`](https://github.com/nvim-neorocks/luarocks-tag-release) -
  upstream LuaRocks publishing action and rockspec generation flow
- [`LuaRocks`](https://luarocks.org) - package hosting, upload API, and
  stable/development manifests
- [`nixpkgs`](https://github.com/NixOS/nixpkgs) - reproducible action runtime
  and Forgejo runner tooling
