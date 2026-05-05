#!/usr/bin/env lua

---@alias forgejo_ref_type 'tag' | 'branch'

---@class (exact) Args
---@field repo_name string The repository name.
---@field forgejo_repo string The forgejo repository (owner/repo_name).
---@field git_server_url string The git server's URL.
---@field git_ref string E.g. a tag or a commit sha.
---@field ref_type forgejo_ref_type
---@field dependencies string[] List of LuaRocks package dependencies.
---@field test_dependencies string[] List of test suite dependencies.
---@field labels string[] List of labels to add to the rockspec.
---@field copy_directories string[] List of directories to add to the rockspec's copy_directories.
---@field summary string Package summary.
---@field detailed_description_lines string[] Detailed description (list of lines).
---@field rockspec_template_file_path string File path to the rockspec template (relative to repo's root).
---@field upload boolean Whether to upload to LuaRocks.
---@field license string|nil License SPDX ID (optional).
---@field extra_luarocks_args string[]
---@field verification_servers string[] LuaRocks servers to try when verifying uploaded packages.
---@field forgejo_event_path string|nil The path to the file on the runner that contains the full event webhook payload.
---@field is_debug boolean Whether to enable debug logging
---@field fail_on_duplicate boolean Whether to fail if the rock version has already been uploaded.

---@param package_name string The name of the LuaRocks package.
---@param package_version string | nil The version of the LuaRocks package.
---@param specrev string the version of the rockspec
---@param args Args
---@return nil
local function luarocks_tag_release(package_name, package_version, specrev, args)
  package_name = package_name:lower()
  -- version in format 3.0 must follow the format '[%w.]+-[%d]+' or be 'dev' or 'scm'
  local modrev = package_version and package_version ~= 'dev' and string.gsub(package_version, 'v', '') or 'scm'

  local rockspec_file_path = package_name .. '-' .. modrev .. '-' .. specrev .. '.rockspec'

  ---@type ltr.OS
  local OS = require('ltr.os')

  local extra_luarocks_args = {}
  for _, arg in ipairs(args.extra_luarocks_args) do
    extra_luarocks_args[#extra_luarocks_args + 1] = arg
  end
  if args.is_debug then
    extra_luarocks_args[#extra_luarocks_args + 1] = '--verbose'
  end

  print('Luarocks flags and args: ' .. OS.command(extra_luarocks_args))

  ---@param base_args string[]
  ---@param additional_args string[]
  ---@return string[]
  local function append_args(base_args, additional_args)
    local result = {}
    for _, arg in ipairs(base_args) do
      result[#result + 1] = arg
    end
    for _, arg in ipairs(additional_args) do
      result[#result + 1] = arg
    end
    return result
  end

  ---@param cmd string
  ---@return string
  local function append_extra_luarocks_args(cmd)
    local rendered_extra_args = OS.command(extra_luarocks_args)
    if rendered_extra_args == '' then
      return cmd
    end
    return cmd .. ' ' .. rendered_extra_args
  end

  ---@param command_args string[]
  ---@return string
  local function luarocks_cmd(command_args)
    return append_extra_luarocks_args(OS.command(command_args))
  end

  ---@return string tmp_dir The temp directory in which to install the package
  ---@return string[] luarocks_install_args The luarocks install command args for installing in tmp_dir
  local function mk_luarocks_install_args()
    local tmp_dir = OS.execute(OS.command { 'mktemp', '-d' }, error, args.is_debug):gsub('\n', '')
    local luarocks_install_args = { 'luarocks', 'install', '--tree', tmp_dir }
    return tmp_dir, luarocks_install_args
  end

  ---Creates a rockspec and performs a local test install
  ---@param rockspec_content string
  ---@return string rockspec_file_path
  local function create_rockspec(rockspec_content)
    local outfile = assert(io.open(rockspec_file_path, 'w'), 'Could not create ' .. rockspec_file_path .. '.')
    outfile:write(rockspec_content)
    outfile:close()
    return rockspec_file_path
  end

  ---@return nil
  local function setup_luarocks_paths()
    print('Getting luarocks path info')
    local luarocks_path_output, _ = OS.execute(OS.command { 'luarocks', 'path' }, error, args.is_debug)
    print('Setting up luarocks paths')
    OS.execute(luarocks_path_output, error, args.is_debug)
  end

  ---@return nil
  local function test_install_rockspec()
    local tmp_dir, luarocks_install_args = mk_luarocks_install_args()
    local cmd = luarocks_cmd(append_args(luarocks_install_args, { rockspec_file_path }))
    print('TEST: ' .. cmd)
    local stdout, _ = OS.execute(cmd, error, args.is_debug)
    print(stdout)
    cmd = luarocks_cmd { 'luarocks', 'remove', '--tree', tmp_dir, package_name }
    print('TEST: ' .. cmd)
    stdout, _ = OS.execute(cmd, error, args.is_debug)
    print(stdout)
  end

  ---@param target_rockspec_path string
  ---@return nil
  local function luarocks_upload(target_rockspec_path)
    local cmd = append_extra_luarocks_args(
      OS.command { 'luarocks', 'upload', target_rockspec_path, '--api-key' } .. ' "$LUAROCKS_API_KEY"'
    )
    print('UPLOAD: ' .. cmd)
    local stdout, _ = OS.execute(cmd, function(message)
      if message:lower():find('already exists') and not args.fail_on_duplicate then
        print(
          string.format(
            '%s already exists with version %s on the remote. Doing nothing (`fail_on_duplicate` is false).',
            package_name,
            package_version
          )
        )
      else
        error(message)
      end
    end, args.is_debug)
    print(stdout)
  end

  ---@return nil
  local function test_install_package()
    local verification_servers = args.verification_servers
    if #verification_servers == 0 then
      verification_servers = { '' }
    end

    local install_version = modrev .. '-' .. specrev
    local last_error = nil
    for _, server in ipairs(verification_servers) do
      local _, luarocks_install_args = mk_luarocks_install_args()
      if server ~= '' then
        luarocks_install_args[#luarocks_install_args + 1] = '--server=' .. server
      end
      local cmd = luarocks_cmd(append_args(luarocks_install_args, { package_name, install_version }))
      print('TEST: ' .. cmd)
      local ok, stdout = pcall(function()
        local output, _ = OS.execute(cmd, error, args.is_debug)
        return output
      end)
      if ok then
        print(stdout)
        return
      end
      last_error = stdout
      print('TEST failed for server "' .. (server ~= '' and server or '<default>') .. '": ' .. tostring(stdout))
    end

    error(last_error or 'Could not verify uploaded package.')
  end

  print('Using template: ' .. args.rockspec_template_file_path)
  local rockspec_template_file =
    assert(io.open(args.rockspec_template_file_path, 'r'), 'Could not open ' .. args.rockspec_template_file_path)
  local rockspec_template = rockspec_template_file:read('*a')
  rockspec_template_file:close()

  print(
    'Generating Luarocks release '
      .. modrev
      .. ' for: '
      .. package_name
      .. ' version '
      .. tostring(package_version)
      .. ' from ref '
      .. args.git_ref
      .. '.'
  )

  local forgejo_event_data = args.forgejo_event_path and OS.read_file(args.forgejo_event_path)
  local json = require('dkjson')

  ---@type ForgejoEvent?
  local forgejo_event_tbl = forgejo_event_data and json.decode(forgejo_event_data)
  ---@type ltr.Rockspec
  local Rockspec = require('ltr.rockspec')
  local rockspec = Rockspec.generate(package_name, modrev, specrev, rockspec_template, {
    ref_type = args.ref_type,
    git_server_url = args.git_server_url,
    forgejo_repo = args.forgejo_repo,
    license = args.license,
    git_ref = args.git_ref,
    summary = args.summary,
    detailed_description_lines = args.detailed_description_lines,
    dependencies = args.dependencies,
    test_dependencies = args.test_dependencies,
    labels = args.labels,
    copy_directories = args.copy_directories,
    repo_name = args.repo_name,
    forgejo_event_tbl = forgejo_event_tbl,
  })

  print('')
  print('Generated ' .. rockspec_file_path .. ':')
  print('========================================================================================')
  print(rockspec)
  print('========================================================================================')

  OS.write_file(rockspec_file_path, rockspec)
  local target_rockspec_path = create_rockspec(rockspec)
  setup_luarocks_paths()
  test_install_rockspec()
  if args.upload then
    luarocks_upload(target_rockspec_path)
    test_install_package()
  else
    print('LuaRocks upload disabled. Skipping...')
  end

  print('')
  print('Done.')
end

return luarocks_tag_release
