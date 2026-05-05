---@diagnostic disable: undefined-global
-- luacheck: globals package version description dependencies source build

local test_template = [[
local git_ref = '$git_ref'
local modrev = '$modrev'
local specrev = '$specrev'

local repo_url = '$repo_url'

rockspec_format = '3.0'
package = '$package'
version = modrev ..'-'.. specrev

description = {
  summary = '$summary',
  detailed = $detailed_description,
  labels = $labels,
  homepage = '$homepage',
  $license
}

dependencies = $dependencies

test_dependencies = $test_dependencies

source = {
  url = repo_url .. '/archive/' .. git_ref .. '.zip',
  dir = '$repo_name',
}

build = {
  type = 'builtin',
  copy_directories = $copy_directories,
}
]]

---@param rockspec_str string The rockspec content
---@return nil
local function load_rockspec(rockspec_str)
  local rockspec_module = assert(loadstring(rockspec_str), 'Could not load generated rockspec')
  rockspec_module()
end

---@return string
local function read_default_template()
  local file = assert(io.open('resources/rockspec.template', 'r'))
  local contents = file:read('*a')
  file:close()
  return contents
end

describe('Rockspec', function()
  ---@type ltr.Rockspec
  local Rockspec = require('ltr.rockspec')
  ---@type GenerateMeta
  local meta = {
    ref_type = 'tag',
    git_server_url = 'https://git.barrettruth.com',
    forgejo_repo = 'barrettruth/luarocks-tag-release-forgejo',
    git_ref = '1.0.0',
    summary = 'test summary',
    detailed_description_lines = { 'a line', 'another line' },
    dependencies = {},
    test_dependencies = {},
    labels = { 'neovim' },
    copy_directories = { 'plugin' },
    repo_name = 'luarocks-tag-release',
  }
  it('Generate (without lua dependency or license)', function()
    load_rockspec(Rockspec.generate('test_package', '1.0.0', '1', test_template, meta))
    assert.same(package, 'test_package')
    assert.same(version, '1.0.0-1')
    assert.same(description, {
      summary = 'test summary',
      detailed = 'a line\nanother line',
      labels = { 'neovim' },
      homepage = 'https://git.barrettruth.com/barrettruth/luarocks-tag-release-forgejo',
    })
    assert.same(build.copy_directories, { 'plugin' })
    assert.same(source.url, 'https://git.barrettruth.com/barrettruth/luarocks-tag-release-forgejo/archive/1.0.0.zip')
    assert.same(source.dir, 'luarocks-tag-release')
    assert.same(dependencies, { 'lua >= 5.1' })
  end)
  it('Generate scm from an archive URL', function()
    meta.ref_type = 'branch'
    meta.git_ref = '0123456789abcdef'
    load_rockspec(Rockspec.generate('test_package', 'scm', '1081', read_default_template(), meta))
    assert.same(version, 'scm-1081')
    assert.same(
      source.url,
      'https://git.barrettruth.com/barrettruth/luarocks-tag-release-forgejo/archive/0123456789abcdef.zip'
    )
    assert.same(source.dir, 'luarocks-tag-release')
    meta.ref_type = 'tag'
    meta.git_ref = '1.0.0'
  end)
  it('Generate (with license)', function()
    meta.license = 'AGPL3'
    load_rockspec(Rockspec.generate('test_package', '1.0.0', '1', test_template, meta))
    assert.same(description.license, 'AGPL3')
  end)
  it('Generate (with lua dependency)', function()
    meta.dependencies = { 'lua >= 5.4' }
    load_rockspec(Rockspec.generate('test_package', '1.0.0', '1', test_template, meta))
    assert.same(dependencies, { 'lua >= 5.4' })
  end)
end)
