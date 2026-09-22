local _MODREV, _SPECREV = 'scm', '-1'
rockspec_format = '3.0'
package = 'luarocks-tag-release'
version = _MODREV .. _SPECREV

description = {
  summary = 'Build and upload LuaRocks packages from Git tags',
  homepage = 'https://forge.barrettruth.com/barrettruth/luarocks-tag-release-forgejo',
  license = 'GPL-3.0',
}

dependencies = {
  'lua >= 5.1',
  'dkjson',
  'luafilesystem',
}

test_dependencies = {
  'dkjson',
  'luafilesystem',
  'nlua',
}

source = {
  url = 'git+https://forge.barrettruth.com/barrettruth/luarocks-tag-release-forgejo.git',
}

build = {
  type = 'builtin',
}
