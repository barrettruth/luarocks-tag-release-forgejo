describe('Action entrypoint', function()
  local function run_action(env_vars)
    local command = 'env -u LUAROCKS_API_KEY -u FORGEJO_ACTION_PATH -u FORGEJO_EVENT_NAME LUA_PATH="lua/?.lua;;" '
      .. table.concat(env_vars, ' ')
      .. ' lua bin/luarocks-tag-release-action.lua 2>&1'
    local handle = assert(io.popen(command))
    local output = handle:read('*a')
    handle:close()
    return output
  end

  it('requires the LuaRocks API key for upload runs', function()
    local output = run_action {}

    assert.matches('LUAROCKS_API_KEY secret not set', output, 1, true)
  end)

  it('does not require the LuaRocks API key for pull request runs', function()
    local output = run_action { 'FORGEJO_EVENT_NAME=pull_request' }

    assert.matches('FORGEJO_ACTION_PATH not set.', output, 1, true)
    assert.not_matches('LUAROCKS_API_KEY secret not set', output, 1, true)
  end)
end)
