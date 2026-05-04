---@alias ltr.FailureHandler fun(error_msg: string): nil

---@class ltr.OS
---@field read_file fun(filename: string): string?
---@field file_exists fun(filename: string): boolean
---@field write_file fun(filename: string, content: string): nil
---@field quote_arg fun(arg: string): string
---@field command fun(args: string[]): string
---@field execute fun(cmd: string, on_failure?: ltr.FailureHandler, verbose?: boolean): string, string
---@field filter_existing_directories fun(directories: string[]): string[]
local OS = {}

---@param filename string
---@return string? content
function OS.read_file(filename)
  local content
  local f = io.open(filename, 'r')
  if f then
    content = f:read('*a')
    f:close()
  end
  return content
end

---@param filename string
---@return boolean file_exists
function OS.file_exists(filename)
  local f = io.open(filename, 'r')
  if f then
    f:close()
    return true
  end
  return false
end

---@param filename string
---@param content string
---@return nil
function OS.write_file(filename, content)
  local outfile = assert(io.open(filename, 'w'), 'Could not create ' .. filename .. '.')
  outfile:write(content)
  outfile:close()
end

---@param arg string
---@return string quoted_arg
function OS.quote_arg(arg)
  if arg == '' then
    return "''"
  end
  return "'" .. arg:gsub("'", "'\\''") .. "'"
end

---@param args string[]
---@return string command
function OS.command(args)
  local quoted_args = {}
  for _, arg in ipairs(args) do
    quoted_args[#quoted_args + 1] = OS.quote_arg(arg)
  end
  return table.concat(quoted_args, ' ')
end

---@param cmd string
---@param on_failure ltr.FailureHandler?
---@param verbose boolean|nil If true, will print stdout and stderr
---@return string stdout, string stderr
function OS.execute(cmd, on_failure, verbose)
  print('RUNNING: ' .. cmd)
  on_failure = on_failure or error
  local exec_out = os.tmpname()
  local exec_err = os.tmpname()
  local to_exec_out = ' >' .. OS.quote_arg(exec_out) .. ' 2>' .. OS.quote_arg(exec_err)
  local exit_code = os.execute(cmd .. to_exec_out)
  local stdout = OS.read_file(exec_out) or ''
  local stderr = OS.read_file(exec_err) or ''
  os.remove(exec_out)
  os.remove(exec_err)
  if exit_code ~= 0 then
    on_failure(cmd .. ' FAILED\nexit code: ' .. exit_code .. '\nstdout: ' .. stdout .. '\nstderr: ' .. stderr)
  elseif verbose then
    print(stdout)
    print(stderr)
  end
  return stdout, stderr
end

---Filter out directories that don't exist.
---@param directories string[] List of directories.
---@return string[] existing_directories
function OS.filter_existing_directories(directories)
  ---@type string[]
  local existing_directories = {}
  for _, dir in pairs(directories) do
    if require('lfs').attributes(dir, 'mode') == 'directory' then
      existing_directories[#existing_directories + 1] = dir
    end
  end
  return existing_directories
end

return OS
