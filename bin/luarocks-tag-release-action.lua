---@type ltr.Parser
local Parser = require('ltr.parser')

---@type ltr.OS
local OS = require('ltr.os')

---@param env_var string
---@return string
local function getenv_or_err(env_var)
  return assert(os.getenv(env_var), env_var .. ' not set.')
end

---@param env_var string
---@return string
local function getenv_or_empty(env_var)
  return os.getenv(env_var) or ''
end

local is_pull_request = getenv_or_empty('FORGEJO_EVENT_NAME') == 'pull_request'
if not is_pull_request then
  assert(os.getenv('LUAROCKS_API_KEY'), 'LUAROCKS_API_KEY secret not set')
end

local action_path = getenv_or_err('FORGEJO_ACTION_PATH')
local forgejo_repo = os.getenv('FORGEJO_REPOSITORY_OVERRIDE') or getenv_or_err('FORGEJO_REPOSITORY')

local repo_name = assert(
  string.match(forgejo_repo, '/(.+)'),
  [[
    Could not determine repository name from FORGEJO_REPOSITORY.
    If you see this, please report this as a bug.
  ]]
)

local git_server_url = os.getenv('GIT_SERVER_URL_OVERRIDE') or getenv_or_err('FORGEJO_SERVER_URL')

local license_input = os.getenv('INPUT_LICENSE')
local template_input = os.getenv('INPUT_TEMPLATE')
local package_name = getenv_or_err('INPUT_NAME')
---@type string|nil
local package_version = is_pull_request and '0.0.0' or os.getenv('INPUT_VERSION')

---@type Args
local args = {
  forgejo_repo = forgejo_repo,
  repo_name = repo_name,
  git_server_url = git_server_url,
  dependencies = Parser.parse_list_args(getenv_or_empty('INPUT_DEPENDENCIES')),
  test_dependencies = Parser.parse_list_args(getenv_or_empty('INPUT_TEST_DEPENDENCIES')),
  labels = Parser.parse_list_args(getenv_or_empty('INPUT_LABELS')),
  copy_directories = OS.filter_existing_directories(
    Parser.parse_copy_directory_args(getenv_or_err('INPUT_COPY_DIRECTORIES'))
  ),
  summary = getenv_or_empty('INPUT_SUMMARY'),
  detailed_description_lines = Parser.parse_list_args(getenv_or_empty('INPUT_DETAILED_DESCRIPTION')),
  rockspec_template_file_path = template_input ~= '' and template_input
    or action_path .. '/resources/rockspec.template',
  upload = not is_pull_request,
  license = license_input ~= '' and license_input or nil,
  extra_luarocks_args = Parser.parse_list_args(getenv_or_empty('INPUT_EXTRA_LUAROCKS_ARGS')),
  verification_servers = Parser.parse_list_args(getenv_or_empty('INPUT_VERIFICATION_SERVERS')),
  forgejo_event_path = getenv_or_err('FORGEJO_EVENT_PATH'),
  ref_type = os.getenv('FORGEJO_REF_TYPE_OVERRIDE') or getenv_or_err('FORGEJO_REF_TYPE'),
  git_ref = os.getenv('FORGEJO_REF_NAME_OVERRIDE') or getenv_or_err('FORGEJO_REF_NAME'),
  is_debug = os.getenv('RUNNER_DEBUG') == '1',
  fail_on_duplicate = getenv_or_empty('INPUT_FAIL_ON_DUPLICATE') == 'true',
}

---@return string
local function get_forgejo_sha()
  return os.getenv('FORGEJO_SHA_OVERRIDE') or getenv_or_err('FORGEJO_SHA')
end

print('Workflow has been triggered by: ' .. args.ref_type)
local is_tag = args.ref_type == 'tag'
if not is_tag then
  print('Publishing an untagged release.')
  args.git_ref = get_forgejo_sha()
end

local luarocks_tag_release = require('luarocks-tag-release')

local specrev
if is_pull_request then
  print('Running in a pull request.')
  specrev = assert(os.getenv('FORGEJO_RUN_ATTEMPT'), 'FORGEJO_RUN_ATTEMPT not set')
  args.git_ref = get_forgejo_sha()
else
  specrev = os.getenv('INPUT_SPECREV') or '1'
end

luarocks_tag_release(package_name, package_version, specrev, args)
